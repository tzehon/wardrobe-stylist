"""Fixed-budget fictional evaluation. Default execution is local and makes zero API calls."""

import argparse
import hashlib
import json
import math
import os
import secrets
import statistics
import time
from dataclasses import dataclass
from decimal import ROUND_CEILING, Decimal
from pathlib import Path
from typing import Any

import anthropic
import jsonschema
from pydantic import ValidationError

from app.agents import stylist
from app.routes.recommend import RecommendRequest, _sanitize_outfit
from app.schemas.recommendation import OutfitRecommendation, TokenUsage
from evaluation.fixtures import Case, cases

PINNED_MODEL = "claude-haiku-4-5-20251001"
OUTPUT_LIMIT = 1024
PROVIDER_CONTEXT_LIMIT = 200_000
PRICING_DATE = "2026-09-06"
PRICING_URL = "https://platform.claude.com/docs/en/about-claude/pricing"
APPROVAL_CEILING_USD = "6.00"
QUALITY_CALLS = 24
QUALITY_FLOOR = {
    "schema_success": 24, "known_ids": 24, "complete_outfits": 24,
    "distinct_alternates": 24, "enough_alternates": 24, "occasion_constraints": 24,
    "avoid_primary_minimum": 3, "avoid_primary_total": 4,
    "prefer_primary_minimum": 3, "prefer_primary_total": 4,
    "p95_latency_seconds_maximum": 20,
    "output_tokens_maximum": OUTPUT_LIMIT,
    "human_reviews_required": 24,
    "human_dimension_mean_minimum": 4,
    "human_individual_score_minimum": 3,
}
HUMAN_DIMENSIONS = ("wearability", "occasion_fit", "preference_fit", "cohesion", "rationale")
SCHEMA_PATH = Path(__file__).resolve().parents[2] / "shared/schemas/outfit.schema.json"


@dataclass(frozen=True)
class ModelProfile:
    model: str
    context_limit: int
    approval_ceiling_usd: str
    input_rate: Decimal
    output_rate: Decimal
    cache_write_rate: Decimal
    cache_read_rate: Decimal


MODEL_PROFILES = {
    PINNED_MODEL: ModelProfile(
        PINNED_MODEL, PROVIDER_CONTEXT_LIMIT, APPROVAL_CEILING_USD,
        Decimal("1"), Decimal("5"), Decimal("1.25"), Decimal("0.10"),
    ),
    "claude-sonnet-5": ModelProfile(
        "claude-sonnet-5", 1_000_000, "58.00",
        Decimal("2"), Decimal("10"), Decimal("2.50"), Decimal("0.20"),
    ),
}


def model_profile(model: str) -> ModelProfile:
    try:
        return MODEL_PROFILES[model]
    except KeyError as exc:
        raise ValueError("Evaluation model must be explicitly allowlisted.") from exc


def canonical(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, ensure_ascii=True, separators=(",", ":")).encode()


def usd(amount: Decimal) -> str:
    return str(amount.quantize(Decimal("0.000001"), rounding=ROUND_CEILING))


def usage_cost(usage: dict[str, int], model: str = PINNED_MODEL) -> Decimal:
    """Selected first-party global model pricing; five-minute explicit caching only."""
    profile = model_profile(model)
    parsed = TokenUsage.model_validate(usage)
    return (
        Decimal(parsed.input_tokens) * profile.input_rate
        + Decimal(parsed.cache_creation_input_tokens) * profile.cache_write_rate
        + Decimal(parsed.cache_read_input_tokens) * profile.cache_read_rate
        + Decimal(parsed.output_tokens) * profile.output_rate
    ) / 1_000_000


def plans(model: str = PINNED_MODEL) -> list[tuple[Case, str, dict[str, Any]]]:
    profile = model_profile(model)
    fixture_cases = cases()
    if len(fixture_cases) != 12:
        raise ValueError("The approved plan requires exactly 12 fictional cases.")
    plan = []
    for fixture in fixture_cases:
        # The real client request validation is deliberately exercised before any paid call.
        validated = RecommendRequest.model_validate(fixture.request).model_dump()
        for _ in range(2):
            params = stylist.build_message_params(
                **validated, max_tokens=OUTPUT_LIMIT, cache_mode="off",
            )
            plan.append((fixture, "quality", params))
    for mode in ("off", "off", "ephemeral", "ephemeral"):
        params = stylist.build_message_params(
            **fixture_cases[0].request, max_tokens=OUTPUT_LIMIT, cache_mode=mode,
        )
        plan.append((fixture_cases[0], "cache_" + mode, params))
    for _, _, params in plan:
        if params["model"] != PINNED_MODEL or params["max_tokens"] != OUTPUT_LIMIT:
            raise ValueError("Model or output limit changed; regenerate and reapprove the plan.")
        if params.get("thinking", {"type": "disabled"}) != {"type": "disabled"} or (
            params.get("stream") or params.get("service_tier") != "standard_only"
        ):
            raise ValueError("Evaluation requires standard synchronous calls without thinking.")
        # Evaluation-only override: production stays pinned to Haiku and the request's other
        # fields remain identical, including strict tools, prompt, cache mode, and output cap.
        params["model"] = profile.model
    return plan


def manifest(model: str = PINNED_MODEL) -> dict[str, Any]:
    profile = model_profile(model)
    plan = plans(model)
    rows = []
    maximum = Decimal(0)
    heuristic = Decimal(0)
    for fixture, purpose, params in plan:
        input_rate = (
            profile.cache_write_rate if purpose == "cache_ephemeral" else profile.input_rate
        )
        # The context ceiling gives the approval bound. Bytes are only a planning estimate,
        # never claimed to prove how Anthropic serializes or tokenizes tool/system messages.
        input_estimate = len(canonical(params)) + 4096
        bound = (
            profile.context_limit * input_rate + OUTPUT_LIMIT * profile.output_rate
        ) / 1_000_000
        estimate = (input_estimate * input_rate + OUTPUT_LIMIT * profile.output_rate) / 1_000_000
        maximum += bound
        heuristic += estimate
        rows.append({
            "case": fixture.name, "purpose": purpose,
            "request_sha256": hashlib.sha256(canonical(params)).hexdigest(),
            "estimated_input_tokens_bytes_plus_overhead": input_estimate,
            "maximum_estimated_usd": usd(bound),
        })
    value = {
        "synthetic_only": True, "model": profile.model, "quality_calls": QUALITY_CALLS,
        "cache_probe_calls": 4, "maximum_calls": len(plan), "sdk_retries": 0,
        "concurrency": 1, "timeout_seconds": 30, "max_output_tokens_per_call": OUTPUT_LIMIT,
        "provider_context_input_ceiling_per_call": profile.context_limit,
        "maximum_estimated_usd": usd(maximum),
        "approval_ceiling_usd": profile.approval_ceiling_usd,
        "heuristic_estimated_usd_at_full_output": usd(heuristic),
        "pricing_verified_date": PRICING_DATE, "pricing_source": PRICING_URL,
        "pricing_usd_per_million": {
            "input": str(profile.input_rate), "output": str(profile.output_rate),
            "cache_write": str(profile.cache_write_rate),
            "cache_read": str(profile.cache_read_rate),
        },
        "quality_floor": QUALITY_FLOOR, "human_dimensions": HUMAN_DIMENSIONS,
        "fixture_expectations_sha256": hashlib.sha256(canonical([
            {"name": c.name, "avoid": sorted(c.avoid_primary), "prefer": sorted(c.prefer_primary),
             "forbid": sorted(c.forbid_primary), "alternates": c.minimum_alternates}
            for c in cases()
        ])).hexdigest(),
        "authoritative_outfit_schema_sha256": hashlib.sha256(SCHEMA_PATH.read_bytes()).hexdigest(),
        "implementation_sha256": hashlib.sha256(b"".join(path.read_bytes() for path in (
            Path(__file__), Path(__file__).with_name("fixtures.py"),
            Path(stylist.__file__), Path(__file__).resolve().parents[1] / "app/routes/recommend.py",
            Path(__file__).resolve().parents[1] / "app/schemas/recommendation.py",
            Path(__file__).resolve().parents[1] / "uv.lock",
            Path(__file__).resolve().parents[1] / "pyproject.toml",
        ))).hexdigest(),
        "calls": rows,
    }
    value["manifest_sha256"] = hashlib.sha256(canonical(value)).hexdigest()
    return value


def evaluate_outfit(
    fixture: Case, tool_input: dict[str, Any], usage: dict[str, int] | None = None,
) -> dict[str, Any]:
    """Judge raw output as well as the production sanitizer; sanitizing is not a model pass."""
    checks: dict[str, Any] = {name: False for name in (
        "schema_success", "known_ids", "complete_outfits", "distinct_alternates",
        "enough_alternates", "occasion_constraints",
    )}
    checks["avoid_primary"] = None
    checks["prefer_primary"] = None
    try:
        token_usage = usage if usage is not None else dict.fromkeys((
            "input_tokens", "output_tokens",
            "cache_creation_input_tokens", "cache_read_input_tokens",
        ), 0)
        jsonschema.validate(
            {**tool_input, "usage": token_usage}, json.loads(SCHEMA_PATH.read_text()),
            format_checker=jsonschema.FormatChecker(),
        )
        raw = OutfitRecommendation.model_validate(tool_input)
        valid = {i["id"] for i in fixture.request["items"]}
        sanitized = _sanitize_outfit(tool_input, valid)
        OutfitRecommendation.model_validate(sanitized)
    except (ValueError, ValidationError, jsonschema.ValidationError, stylist.StylistError):
        return checks
    checks["schema_success"] = True
    outfits = [raw.item_ids, *(alt.item_ids for alt in raw.alternates)]
    checks["known_ids"] = all(set(ids) <= valid for ids in outfits)
    category_by_id = {i["id"]: i["category"] for i in fixture.request["items"]}

    def complete(ids: list[str]) -> bool:
        categories = {category_by_id.get(identifier) for identifier in ids}
        return len(ids) == len(set(ids)) and "shoe" in categories and (
            "dress" in categories or {"top", "bottom"} <= categories
        )

    checks["complete_outfits"] = all(complete(ids) for ids in outfits)
    checks["distinct_alternates"] = len({frozenset(ids) for ids in outfits}) == len(outfits)
    checks["enough_alternates"] = len(raw.alternates) >= fixture.minimum_alternates
    primary = set(raw.item_ids)
    checks["occasion_constraints"] = not bool(primary & fixture.forbid_primary)
    if fixture.avoid_primary:
        checks["avoid_primary"] = not bool(primary & fixture.avoid_primary)
    if fixture.prefer_primary:
        checks["prefer_primary"] = bool(primary & fixture.prefer_primary)
    return checks


def automatic_decision(rows: list[dict[str, Any]]) -> dict[str, Any]:
    quality = [row for row in rows if row["purpose"] == "quality"]
    counts = {
        name: sum(row.get("checks", {}).get(name) is True for row in quality)
        for name in ("schema_success", "known_ids", "complete_outfits", "distinct_alternates",
                     "enough_alternates", "occasion_constraints", "avoid_primary", "prefer_primary")
    }
    latencies = sorted(row["latency_seconds"] for row in quality)
    p95 = latencies[math.ceil(0.95 * len(latencies)) - 1] if latencies else None
    passed = len(quality) == QUALITY_CALLS and all(
        counts[name] == QUALITY_CALLS for name in (
            "schema_success", "known_ids", "complete_outfits", "distinct_alternates",
            "enough_alternates", "occasion_constraints",
        )
    ) and counts["avoid_primary"] >= 3 and counts["prefer_primary"] >= 3
    passed = passed and p95 is not None and p95 <= 20
    passed = passed and all(
        row.get("usage", {}).get("output_tokens", OUTPUT_LIMIT + 1) <= OUTPUT_LIMIT
        and row.get("status") == "ok" for row in quality
    )
    return {"passed": passed, "counts": counts, "p95_latency_seconds": p95}


def score_review(report: dict[str, Any], scores: list[dict[str, Any]]) -> dict[str, Any]:
    """Require one complete, blinded human score card per quality call before acceptance."""
    expected = {row["blind_id"] for row in report["rows"] if row["purpose"] == "quality"}
    supplied = [row.get("blind_id") for row in scores]
    if len(expected) != QUALITY_CALLS or len(supplied) != len(set(supplied)):
        raise ValueError("Exactly 24 unique complete blinded reviews are required.")
    if set(supplied) != expected:
        raise ValueError("Review identifiers do not match this complete evaluation.")
    for row in scores:
        if set(row) != {"blind_id", *HUMAN_DIMENSIONS}:
            raise ValueError("Each review must contain exactly the five rubric dimensions.")
        if any(type(row[key]) is not int or not 1 <= row[key] <= 5 for key in HUMAN_DIMENSIONS):
            raise ValueError("Every human dimension must be an integer from 1 to 5.")
    means = {key: statistics.mean(row[key] for row in scores) for key in HUMAN_DIMENSIONS}
    human_pass = all(value >= 4 for value in means.values()) and all(
        row[key] >= 3 for row in scores for key in HUMAN_DIMENSIONS
    )
    automatic = automatic_decision(report["rows"])
    accepted = automatic["passed"] and human_pass and report["complete"]
    return {
        "accepted": accepted, "automatic": automatic, "human_passed": human_pass,
        "human_dimension_means": means,
        "next_step": "owner model acceptance and measured budget decision" if accepted else
        "inspect failure; further evaluation requires a separately approved model plan",
    }


def cache_decision(rows: list[dict[str, Any]], model: str = PINNED_MODEL) -> dict[str, Any]:
    profile = model_profile(model)
    probe = [row for row in rows if row["purpose"].startswith("cache_")]
    if len(probe) != 4 or any(row["status"] != "ok" for row in probe):
        return {"status": "incomplete", "retain_caching": False}
    cached = [row for row in probe if row["purpose"] == "cache_ephemeral"]
    writes = sum(row["usage"]["cache_creation_input_tokens"] for row in cached)
    reads = sum(row["usage"]["cache_read_input_tokens"] for row in cached)
    # Compare input only: differences in generated output length must not mimic cache savings.
    counterfactual = sum(sum(row["usage"][key] for key in (
        "input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens",
    )) for row in cached) * profile.input_rate / Decimal(1_000_000)
    actual = sum(usage_cost({**row["usage"], "output_tokens": 0}, model) for row in cached)
    return {
        "status": "measured", "cache_write_tokens": writes, "cache_read_tokens": reads,
        "cached_input_cost_usd": usd(actual), "uncached_counterfactual_usd": usd(counterfactual),
        "retain_caching": reads > 0 and actual < counterfactual,
        "note": "A warm two-call result does not establish production reuse within five minutes.",
    }


def _append_accounting(path: Path, event: str, rows: list[dict[str, Any]]) -> None:
    """Flush aggregate evidence before a provider attempt can acquire an uncertain charge."""
    record = {
        "event": event, "attempted_calls": len(rows),
        "latest_status": rows[-1]["status"] if rows else "not_started",
        "maximum_attempted_cost_usd": usd(sum(
            (Decimal(row["reserved_maximum_usd"]) for row in rows), Decimal(0),
        )),
        "known_cost_usd": usd(sum(
            (Decimal(row.get("calculated_cost_usd", "0")) for row in rows), Decimal(0),
        )),
    }
    with path.open("a") as stream:
        stream.write(json.dumps(record, sort_keys=True) + "\n")
        stream.flush()
        os.fsync(stream.fileno())


def _sync_directory(path: Path) -> None:
    descriptor = os.open(path, os.O_RDONLY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def live_run(
    approved_hash: str, approved_max_usd: str, output_dir: Path, *, model: str = PINNED_MODEL,
) -> dict[str, Any]:
    profile = model_profile(model)
    approved = manifest(model)
    if (approved_hash != approved["manifest_sha256"]
            or approved_max_usd != profile.approval_ceiling_usd):
        raise ValueError("Explicit owner approval must match this manifest and its USD ceiling.")
    maximum = Decimal(approved["maximum_estimated_usd"])
    ceiling = Decimal(approved_max_usd)
    if not maximum.is_finite() or maximum <= 0 or maximum > ceiling:
        raise ValueError("Calculated maximum cost must fit the independent approval ceiling.")
    key = os.environ.get("EVAL_ANTHROPIC_API_KEY")
    if not key:
        raise ValueError("Set owner-authorized EVAL_ANTHROPIC_API_KEY without printing its value.")
    # A new directory prevents an accidental rerun from overwriting approval evidence.
    output_dir.mkdir(parents=True, exist_ok=False, mode=0o700)
    journal = output_dir / "accounting.jsonl"
    journal.touch(mode=0o600, exist_ok=False)
    with journal.open("a") as stream:
        stream.write(json.dumps({
            "event": "run_started", "manifest_sha256": approved["manifest_sha256"],
            "maximum_calls": approved["maximum_calls"],
            "maximum_estimated_usd": approved["maximum_estimated_usd"],
            "approval_ceiling_usd": approved_max_usd,
        }, sort_keys=True) + "\n")
        stream.flush()
        os.fsync(stream.fileno())
    _sync_directory(output_dir)
    _sync_directory(output_dir.parent)
    rows: list[dict[str, Any]] = []
    review = []
    report: dict[str, Any] = {"manifest": approved, "rows": rows, "complete": False}
    # Explicit endpoint prevents ANTHROPIC_BASE_URL from redirecting evaluation credentials.
    # SDK v1 explicit api_key disables credential discovery, including environment bearer auth.
    with anthropic.Anthropic(
        api_key=key, base_url="https://api.anthropic.com", max_retries=0, timeout=30,
    ) as client:
        for index, (fixture, purpose, params) in enumerate(plans(model)):
            started = time.monotonic()
            row: dict[str, Any] = {
                "case": fixture.name, "purpose": purpose, "blind_id": secrets.token_hex(8),
                "status": "attempt_reserved",
                "reserved_maximum_usd": approved["calls"][index]["maximum_estimated_usd"],
            }
            rows.append(row)
            # Failure to persist the debit fails closed before messages.create. A killed process
            # leaves the full reserved charge, even if no response or final report survives.
            _append_accounting(journal, "attempt_reserved", rows)
            try:
                response = client.messages.create(**params)
                # Preserve usage even when truncation/tool extraction fails.
                usage = response.usage
                row["usage"] = TokenUsage.model_validate({
                    "input_tokens": usage.input_tokens, "output_tokens": usage.output_tokens,
                    "cache_creation_input_tokens": usage.cache_creation_input_tokens or 0,
                    "cache_read_input_tokens": usage.cache_read_input_tokens or 0,
                }).model_dump()
                if (
                    sum(row["usage"][key] for key in (
                        "input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens",
                    )) > profile.context_limit or row["usage"]["output_tokens"] > OUTPUT_LIMIT
                ):
                    # A response outside the priced profile cannot settle the conservative debit
                    # or enter the quality packet. Keep the observed counters for diagnosis only.
                    row["status"] = "token_boundary_breach_run_stopped"
                    break
                row["calculated_cost_usd"] = usd(usage_cost(row["usage"], model))
                result = stylist.extract_response(response)
                row["checks"] = evaluate_outfit(fixture, result["tool_input"], row["usage"])
                row["status"] = "ok"
                if purpose == "quality":
                    review.append({
                        "blind_id": row["blind_id"], "fictional_request": fixture.request,
                        "outfit": result["tool_input"],
                    })
            except anthropic.APIError:
                row["status"] = "provider_error_run_stopped"
                # Do not retry an uncertain paid request or serialize SDK error/response bodies.
                break
            except KeyboardInterrupt:
                row["status"] = "interrupted_run_stopped"
                break
            except (ValueError, stylist.StylistError):
                row["status"] = "invalid_response"
            finally:
                row["latency_seconds"] = round(time.monotonic() - started, 3)
                _append_accounting(
                    journal, "attempt_uncertain" if row["status"] == "attempt_reserved"
                    else "attempt_finished", rows,
                )
    report["complete"] = len(rows) == approved["maximum_calls"] and all(
        row["status"] == "ok" for row in rows
    )
    report["automatic"] = automatic_decision(rows)
    report["cache"] = cache_decision(rows, model)
    report["quality_accepted"] = False
    report["human_review"] = "pending"
    report["known_cost_usd"] = usd(sum(
        (Decimal(row.get("calculated_cost_usd", "0")) for row in rows), Decimal(0),
    ))
    report["maximum_attempted_cost_usd"] = usd(sum(
        (Decimal(row["reserved_maximum_usd"]) for row in rows), Decimal(0),
    ))
    quality_rows = [row for row in rows if row["purpose"] == "quality"]
    usable = sum(
        all(row.get("checks", {}).get(key) for key in (
            "schema_success", "known_ids", "complete_outfits",
        )) for row in quality_rows
    )
    quality_cost = sum(
        (Decimal(row.get("calculated_cost_usd", "0")) for row in quality_rows), Decimal(0),
    )
    report["usable_quality_recommendations"] = usable
    report["known_quality_cost_per_usable_recommendation_usd"] = (
        usd(quality_cost / usable) if usable else None
    )
    report["usage_complete"] = all(
        "usage" in row and row["status"] != "token_boundary_breach_run_stopped" for row in rows
    )
    report["token_totals"] = {
        key: sum(row.get("usage", {}).get(key, 0) for row in rows)
        for key in ("input_tokens", "output_tokens", "cache_creation_input_tokens",
                    "cache_read_input_tokens")
    }
    secrets.SystemRandom().shuffle(review)
    artifacts = {
        "report.json": report,
        "blinded-review.json": {"rubric": HUMAN_DIMENSIONS, "cases": review},
        "scores.json": [{"blind_id": row["blind_id"], **dict.fromkeys(HUMAN_DIMENSIONS)}
                        for row in review],
    }
    for name, value in artifacts.items():
        path = output_dir / name
        with path.open("x") as stream:
            json.dump(value, stream, indent=2)
            stream.write("\n")
        path.chmod(0o600)
    _append_accounting(journal, "run_finished", rows)
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command", choices=("dry-run", "live", "score"), nargs="?", default="dry-run",
    )
    parser.add_argument("--model", choices=tuple(MODEL_PROFILES), default=PINNED_MODEL)
    parser.add_argument("--approved-manifest-sha256")
    parser.add_argument("--approved-max-usd")
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--scores", type=Path)
    args = parser.parse_args(argv)
    exit_status = 0
    try:
        if args.command == "dry-run":
            result = manifest(args.model)
        elif args.command == "live":
            if not all((args.approved_manifest_sha256, args.approved_max_usd, args.output_dir)):
                parser.error("live requires approved hash, USD ceiling, and new output directory")
            result = live_run(
                args.approved_manifest_sha256, args.approved_max_usd, args.output_dir,
                model=args.model,
            )
            if not result["complete"]:
                exit_status = 130 if any(
                    row["status"] == "interrupted_run_stopped" for row in result["rows"]
                ) else 2
            # Terminal gets aggregate fields only; synthetic review material remains in artifacts.
            result = {key: result[key] for key in (
                "complete", "automatic", "cache", "known_cost_usd", "maximum_attempted_cost_usd",
            )}
        else:
            if not args.report or not args.scores:
                parser.error("score requires the saved report and completed blinded scores")
            result = score_review(
                json.loads(args.report.read_text()), json.loads(args.scores.read_text()),
            )
    except KeyboardInterrupt:
        parser.exit(130, "Evaluation interrupted. Retain the accounting journal; do not retry.\n")
    except (OSError, ValueError) as exc:
        # Never print credentials, SDK errors, or user file bodies.
        parser.exit(
            2, f"Evaluation stopped: {type(exc).__name__}. Check approval and local inputs.\n",
        )
    print(json.dumps(result, indent=2))
    return exit_status


if __name__ == "__main__":
    raise SystemExit(main())
