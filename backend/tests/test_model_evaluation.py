"""The acceptance workflow's safety/cost/quality gates use fictional SDK responses only."""

import json
from copy import deepcopy
from dataclasses import replace
from decimal import Decimal
from pathlib import Path
from types import SimpleNamespace
from typing import Any

import anthropic
import httpx2
import pytest
from anthropic.types import ToolUseBlock

from evaluation import run
from evaluation.fixtures import Case, cases, catalog_id


def outfit(fixture: Case) -> dict[str, Any]:
    if fixture.name == "large_catalog":
        primary, alternate = ["large-0", "large-1", "large-2"], ["large-3", "large-4", "large-5"]
    elif fixture.name == "tiny_dress":
        primary, alternate = ["d1", "s1"], []
    elif fixture.name == "black_palette":
        primary, alternate = ["t3", "b3", "s1"], ["t3", "b3", "s1", "a1"]
    elif fixture.name in {"office", "wedding"}:
        primary, alternate = ["t1", "b1", "s1"], ["d1", "s1"]
    else:
        primary, alternate = ["t2", "b2", "s2"], ["d1", "s1"]
    return {
        "occasion": "Fictional day", "color_story": "A coherent palette.",
        "rationale": "Fictional review sample.", "item_ids": [catalog_id(i) for i in primary],
        "alternates": [{"item_ids": [catalog_id(i) for i in alternate],
                        "rationale": "Another coherent option."}]
        if alternate else [],
    }


def install_fake(monkeypatch: pytest.MonkeyPatch, *, failure: str | None = None) -> dict[str, Any]:
    state: dict[str, Any] = {
        "calls": [], "client_options": {},
        "usage": {"input_tokens": 200, "output_tokens": 100,
                  "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0},
    }

    class Client:
        def __init__(self, **kwargs: Any):
            state["client_options"] = kwargs
            self.messages = self

        def __enter__(self):
            return self

        def __exit__(self, *args: Any):
            return False

        def create(self, **params: Any):
            index = len(state["calls"])
            if state.get("journal_path"):
                journal = [
                    json.loads(line) for line in state["journal_path"].read_text().splitlines()
                ]
                assert journal[-1]["event"] == "attempt_reserved"
                assert journal[-1]["attempted_calls"] == index + 1
            state["calls"].append(params)
            if failure == "connection":
                raise anthropic.APIConnectionError(request=httpx2.Request("POST", "https://example.test"))
            if failure == "interrupt":
                raise KeyboardInterrupt
            if failure == "exit":
                raise SystemExit("private-error-text-must-not-enter-journal")
            fixture, _, _ = run.plans(params["model"])[index]
            return SimpleNamespace(
                stop_reason="max_tokens" if failure == "truncation" else "tool_use",
                content=[ToolUseBlock(type="tool_use", id="fake", name="propose_outfit",
                                      input=outfit(fixture))],
                usage=SimpleNamespace(**state["usage"]),
            )

    monkeypatch.setattr(run.anthropic, "Anthropic", Client)
    monkeypatch.setenv("EVAL_ANTHROPIC_API_KEY", "fictional-evaluation-test-key")
    return state


def fake_run(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path, *,
    model: str = run.PINNED_MODEL, **kwargs: Any,
):
    state = install_fake(monkeypatch, **kwargs)
    output = tmp_path / "new-run"
    state["journal_path"] = output / "accounting.jsonl"
    approved = run.manifest(model)
    report = run.live_run(
        approved["manifest_sha256"], approved["approval_ceiling_usd"], output, model=model,
    )
    return state, report, output


def test_default_command_never_constructs_client(monkeypatch, capsys):
    def forbidden(**kwargs):
        pytest.fail("An offline dry run must not construct an API client.")

    monkeypatch.setattr(run.anthropic, "Anthropic", forbidden)
    assert run.main([]) == 0
    manifest = json.loads(capsys.readouterr().out)
    assert manifest["model"] == run.stylist.MODEL == "claude-sonnet-5"
    assert manifest["maximum_calls"] == 28
    assert manifest["maximum_estimated_usd"] == "57.286720"
    assert manifest["approval_ceiling_usd"] == "58.00"
    assert manifest["max_output_tokens_per_call"] == 1024
    assert manifest["maximum_calls"] == len(manifest["calls"])
    assert len({row["case"] for row in manifest["calls"]}) == 12


def test_plan_uses_exact_production_builder_without_thinking_or_retries():
    assert run.manifest() == run.manifest()
    for fixture, purpose, params in run.plans():
        assert params["model"] == "claude-sonnet-5"
        assert params == run.stylist.build_message_params(
            **run.RecommendRequest.model_validate(fixture.request).model_dump(),
            max_tokens=1024,
            cache_mode="ephemeral" if purpose == "cache_ephemeral" else "off",
        )
        assert params["thinking"] == {"type": "disabled"}
        assert params["max_tokens"] == 1024
        assert params["tools"][0]["strict"] is True
        assert params["tool_choice"]["name"] == "propose_outfit"


def test_haiku_is_an_explicit_legacy_override_without_mutating_production():
    sonnet = run.plans()
    haiku = run.plans(run.HAIKU_MODEL)
    for (old_case, old_purpose, old_params), (new_case, new_purpose, new_params) in zip(
        sonnet, haiku, strict=True,
    ):
        assert old_case == new_case
        assert old_purpose == new_purpose
        assert new_params == {**old_params, "model": run.HAIKU_MODEL}
    assert run.stylist.MODEL == run.PINNED_MODEL
    assert run.plans() == sonnet


def test_sonnet_dry_run_binds_full_context_pricing_and_ceiling_without_client(monkeypatch, capsys):
    def forbidden(**kwargs):
        pytest.fail("Preparing a Sonnet profile must not create an API client.")

    monkeypatch.setattr(run.anthropic, "Anthropic", forbidden)
    assert run.main(["dry-run", "--model", "claude-sonnet-5"]) == 0
    approved = json.loads(capsys.readouterr().out)
    haiku = run.manifest(run.HAIKU_MODEL)
    assert approved["model"] == "claude-sonnet-5"
    assert approved["provider_context_input_ceiling_per_call"] == 1_000_000
    assert approved["maximum_estimated_usd"] == "57.286720"
    assert approved["approval_ceiling_usd"] == "58.00"
    assert approved["pricing_usd_per_million"] == {
        "input": "2", "output": "10", "cache_write": "2.50", "cache_read": "0.20",
    }
    assert [row["maximum_estimated_usd"] for row in approved["calls"]] == (
        ["2.010240"] * 26 + ["2.510240"] * 2
    )
    for key in (
        "maximum_calls", "quality_calls", "cache_probe_calls", "quality_floor",
        "sdk_retries", "concurrency", "timeout_seconds", "max_output_tokens_per_call",
        "fixture_expectations_sha256", "authoritative_outfit_schema_sha256",
        "implementation_sha256",
    ):
        assert approved[key] == haiku[key]
    assert approved["manifest_sha256"] != haiku["manifest_sha256"]
    assert haiku["maximum_estimated_usd"] == "5.843360"
    assert haiku["provider_context_input_ceiling_per_call"] == 200_000
    assert haiku["approval_ceiling_usd"] == "6.00"


def test_unlisted_model_cannot_prepare_or_start_an_evaluation(monkeypatch, tmp_path, capsys):
    def forbidden(**kwargs):
        pytest.fail("An unlisted model must fail before API client construction.")

    monkeypatch.setattr(run.anthropic, "Anthropic", forbidden)
    for prepare in (run.plans, run.manifest):
        with pytest.raises(ValueError, match="allowlisted"):
            prepare("claude-sonnet-latest")
    with pytest.raises(ValueError, match="allowlisted"):
        run.live_run("unused", "58.00", tmp_path / "unused", model="claude-sonnet-latest")
    with pytest.raises(SystemExit) as rejected:
        run.main(["dry-run", "--model", "claude-sonnet-latest"])
    assert rejected.value.code == 2
    assert "invalid choice" in capsys.readouterr().err
    assert not (tmp_path / "unused").exists()


@pytest.mark.parametrize("approved_model,selected_model,ceiling", [
    (run.HAIKU_MODEL, "claude-sonnet-5", "58.00"),
    ("claude-sonnet-5", run.HAIKU_MODEL, "6.00"),
    ("claude-sonnet-5", "claude-sonnet-5", "6.00"),
])
def test_model_approval_cannot_cross_profiles_or_reuse_haiku_ceiling(
    monkeypatch, tmp_path, approved_model, selected_model, ceiling,
):
    def forbidden(**kwargs):
        pytest.fail("Model and ceiling approval must be checked before client construction.")

    monkeypatch.setattr(run.anthropic, "Anthropic", forbidden)
    approved = run.manifest(approved_model)
    with pytest.raises(ValueError, match="approval"):
        run.live_run(
            approved["manifest_sha256"], ceiling, tmp_path / "unused", model=selected_model,
        )
    assert not (tmp_path / "unused").exists()


@pytest.mark.parametrize("field,value", [
    ("context_limit", 200_000), ("input_rate", Decimal("3")),
    ("cache_read_rate", Decimal("0.30")), ("approval_ceiling_usd", "59.00"),
])
def test_changed_sonnet_profile_invalidates_source_bound_approval(
    monkeypatch, tmp_path, field, value,
):
    model = "claude-sonnet-5"
    approved = run.manifest(model)
    profile = replace(run.model_profile(model), **{field: value})
    monkeypatch.setitem(run.MODEL_PROFILES, model, profile)
    assert run.manifest(model)["manifest_sha256"] != approved["manifest_sha256"]

    def forbidden(**kwargs):
        pytest.fail("Changed profile must require fresh approval before client construction.")

    monkeypatch.setattr(run.anthropic, "Anthropic", forbidden)
    with pytest.raises(ValueError, match="approval"):
        run.live_run(
            approved["manifest_sha256"], profile.approval_ceiling_usd, tmp_path / "unused",
            model=model,
        )
    assert not (tmp_path / "unused").exists()


@pytest.mark.parametrize("relative_path", [
    "app/schemas/recommendation.py", "uv.lock", "pyproject.toml", "evaluation/run.py",
])
def test_manifest_binds_local_model_and_locked_sdk_sources(monkeypatch, relative_path):
    baseline = run.manifest()
    changed = Path(run.__file__).resolve().parents[1] / relative_path
    original = Path.read_bytes

    def changed_read(path):
        content = original(path)
        return content + b"\nfictional hash change" if path == changed else content

    monkeypatch.setattr(Path, "read_bytes", changed_read)
    updated = run.manifest()
    assert updated["implementation_sha256"] != baseline["implementation_sha256"]
    assert updated["manifest_sha256"] != baseline["manifest_sha256"]


@pytest.mark.parametrize("model", [run.HAIKU_MODEL, "claude-sonnet-5"])
def test_real_sdk_transport_uses_only_explicit_eval_key_and_standard_tier(
    monkeypatch, tmp_path, model,
):
    real_client = anthropic.Anthropic
    observed = []
    plan = run.plans(model)
    monkeypatch.setenv("EVAL_ANTHROPIC_API_KEY", "fictional-explicit-eval-key")
    monkeypatch.setenv("ANTHROPIC_AUTH_TOKEN", "hostile-environment-bearer")
    monkeypatch.setenv("ANTHROPIC_API_KEY", "hostile-environment-api-key")
    monkeypatch.setenv("ANTHROPIC_BASE_URL", "https://hostile.example.test")

    def handle(request):
        assert request.url.host == "api.anthropic.com"
        assert request.headers["x-api-key"] == "fictional-explicit-eval-key"
        assert "authorization" not in request.headers
        body = json.loads(request.content)
        assert body["service_tier"] == "standard_only"
        assert body["model"] == model
        assert body["thinking"] == {"type": "disabled"}
        fixture, _, _ = plan[len(observed)]
        observed.append(body)
        return httpx2.Response(200, json={
            "id": "msg_fictional", "type": "message", "role": "assistant",
            "model": model, "stop_reason": "tool_use", "stop_sequence": None,
            "content": [{"type": "tool_use", "id": "tool_fictional", "name": "propose_outfit",
                         "input": outfit(fixture)}],
            "usage": {"input_tokens": 200, "output_tokens": 100,
                      "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0},
        })

    def factory(**kwargs):
        assert "auth_token" not in kwargs
        return real_client(
            **kwargs, http_client=httpx2.Client(transport=httpx2.MockTransport(handle)),
        )

    monkeypatch.setattr(run.anthropic, "Anthropic", factory)
    approved = run.manifest(model)
    report = run.live_run(
        approved["manifest_sha256"], approved["approval_ceiling_usd"], tmp_path / "new-run",
        model=model,
    )
    assert len(observed) == 28
    assert report["complete"]
    assert report["automatic"]["passed"]


@pytest.mark.parametrize("bad_hash,bad_budget", [("wrong", "58.00"), (None, "6.00"), (None, "58")])
def test_approval_mismatch_cannot_construct_client(monkeypatch, tmp_path, bad_hash, bad_budget):
    def forbidden(**kwargs):
        pytest.fail("Approval must be verified before constructing an API client.")

    monkeypatch.setattr(run.anthropic, "Anthropic", forbidden)
    with pytest.raises(ValueError, match="approval"):
        run.live_run(bad_hash or run.manifest()["manifest_sha256"], bad_budget, tmp_path / "unused")
    assert not (tmp_path / "unused").exists()


def test_production_key_is_never_used(monkeypatch, tmp_path):
    monkeypatch.delenv("EVAL_ANTHROPIC_API_KEY", raising=False)
    monkeypatch.setenv("ANTHROPIC_API_KEY", "production-key-must-not-be-used")
    with pytest.raises(ValueError, match="EVAL_ANTHROPIC_API_KEY"):
        run.live_run(run.manifest()["manifest_sha256"], "58.00", tmp_path / "unused")


@pytest.mark.parametrize("maximum", ["58.000001", "59", "NaN", "Infinity", "0", "-1"])
def test_hash_cannot_bypass_independent_numeric_cost_ceiling(monkeypatch, tmp_path, maximum):
    approved = run.manifest()
    approved["maximum_estimated_usd"] = maximum
    monkeypatch.setattr(run, "manifest", lambda model=run.PINNED_MODEL: approved)

    def forbidden(**kwargs):
        pytest.fail("Cost must fit the approval before client construction.")

    monkeypatch.setattr(run.anthropic, "Anthropic", forbidden)
    with pytest.raises(ValueError, match="approval ceiling"):
        run.live_run(approved["manifest_sha256"], "58.00", tmp_path / "unused")
    assert not (tmp_path / "unused").exists()


@pytest.mark.parametrize("maximum", ["6.000001", "NaN"])
def test_haiku_hash_cannot_bypass_its_independent_numeric_ceiling(monkeypatch, tmp_path, maximum):
    model = run.HAIKU_MODEL
    approved = run.manifest(model)
    approved["maximum_estimated_usd"] = maximum
    monkeypatch.setattr(run, "manifest", lambda model=run.PINNED_MODEL: approved)

    def forbidden(**kwargs):
        pytest.fail("Haiku's numeric ceiling must be enforced before client construction.")

    monkeypatch.setattr(run.anthropic, "Anthropic", forbidden)
    with pytest.raises(ValueError, match="approval ceiling"):
        run.live_run(approved["manifest_sha256"], "6.00", tmp_path / "unused", model=model)
    assert not (tmp_path / "unused").exists()


def test_all_fictional_expected_outfits_pass_objective_checks():
    for fixture in cases():
        checks = run.evaluate_outfit(fixture, outfit(fixture))
        assert all(value is not False for value in checks.values()), fixture.name


def test_raw_hallucination_is_failure_even_when_sanitizer_could_salvage():
    fixture = cases()[0]
    payload = outfit(fixture)
    payload["item_ids"].append(catalog_id("not-in-catalog"))
    checks = run.evaluate_outfit(fixture, payload)
    assert checks["schema_success"]
    assert not checks["known_ids"]


def test_completeness_distinctness_and_schema_are_separate():
    fixture = cases()[0]
    payload = outfit(fixture)
    payload["item_ids"] = [catalog_id(i) for i in ("t1", "b1")]
    assert not run.evaluate_outfit(fixture, payload)["complete_outfits"]
    payload = outfit(fixture)
    payload["alternates"][0]["item_ids"] = payload["item_ids"]
    assert not run.evaluate_outfit(fixture, payload)["distinct_alternates"]
    payload = outfit(fixture)
    payload["extra"] = "unsupported"
    assert not run.evaluate_outfit(fixture, payload)["schema_success"]


@pytest.mark.parametrize((
    "case_name", "primary", "alternates", "failed_check", "corrected_primary", "corrected_alts",
), [
    pytest.param(
        "black_palette", ["t3", "b3", "s1", "a1"], [["t3", "b3", "s1", "a1"]],
        "distinct_alternates", ["t3", "b3", "s1", "a1"], [["t3", "b3", "s1"]],
        id="black-palette-sole-alternate-repeats-primary",
    ),
    pytest.param(
        "black_palette", ["t3", "b3", "s1", "a1"],
        [["t3", "b3", "s1"], ["t3", "b3", "s1", "a1"]],
        "distinct_alternates", ["t3", "b3", "s1", "a1"], [["t3", "b3", "s1"]],
        id="black-palette-valid-first-alternate-does-not-excuse-duplicate-second",
    ),
    pytest.param(
        "all_recent", ["b2", "o1", "s3", "a1"],
        [["d1", "s1", "a1"], ["t1", "b3", "s3"]],
        "complete_outfits", ["t2", "b2", "o1", "s3", "a1"],
        [["d1", "s1", "a1"], ["t1", "b3", "s3"]],
        id="all-recent-outerwear-does-not-replace-missing-top",
    ),
])
def test_saved_haiku_failure_shapes_remain_failures_under_unchanged_evaluator(
    case_name, primary, alternates, failed_check, corrected_primary, corrected_alts,
):
    # Replay only the fictional item selections from the failed run, with neutral test prose.
    # Prompt changes cannot turn the original outputs into passing acceptance evidence.
    fixture = next(case for case in cases() if case.name == case_name)
    payload = outfit(fixture)

    def set_looks(primary_labels, alternate_labels):
        payload["item_ids"] = [catalog_id(label) for label in primary_labels]
        payload["alternates"] = [
            {"item_ids": [catalog_id(label) for label in labels],
             "rationale": f"Fictional alternative {index}."}
            for index, labels in enumerate(alternate_labels)
        ]

    set_looks(primary, alternates)
    original = deepcopy(payload)
    checks = run.evaluate_outfit(fixture, payload)
    assert checks["schema_success"] and checks["known_ids"]
    assert checks["enough_alternates"] and checks["occasion_constraints"]
    assert checks[failed_check] is False
    other_check = (
        "complete_outfits" if failed_check == "distinct_alternates" else "distinct_alternates"
    )
    assert checks[other_check] is True
    assert payload == original

    if failed_check == "distinct_alternates":
        # A different order or rationale cannot make the same item set an alternate.
        payload["alternates"][-1]["item_ids"].reverse()
        payload["alternates"][-1]["rationale"] = "A different description of the same items."
        assert not run.evaluate_outfit(fixture, payload)["distinct_alternates"]

    set_looks(corrected_primary, corrected_alts)
    assert all(value is not False for value in run.evaluate_outfit(fixture, payload).values())


def test_raw_occasion_recent_wear_and_rating_regressions_fail():
    fixtures = {case.name: case for case in cases()}
    payload = outfit(fixtures["office"])
    payload["item_ids"] = [catalog_id(i) for i in ("t1", "b1", "s3")]
    assert not run.evaluate_outfit(fixtures["office"], payload)["occasion_constraints"]
    assert not run.evaluate_outfit(fixtures["recent_rotation"], payload)["avoid_primary"]
    assert not run.evaluate_outfit(fixtures["positive_preference"], payload)["prefer_primary"]


@pytest.mark.parametrize("optional_in_primary", [True, False], ids=["remove-bag", "add-bag"])
def test_optional_item_variation_satisfies_unchanged_required_alternate_floor(optional_in_primary):
    fixture = next(case for case in cases() if case.name == "black_palette")
    payload = outfit(fixture)
    core = [catalog_id(label) for label in ("t3", "b3", "s1")]
    with_bag = [*core, catalog_id("a1")]
    payload["item_ids"] = with_bag if optional_in_primary else core
    payload["alternates"] = []
    original = deepcopy(payload)
    checks = run.evaluate_outfit(fixture, payload)
    assert checks["enough_alternates"] is False
    assert all(value is not False for key, value in checks.items() if key != "enough_alternates")
    assert payload == original  # Evaluation must not synthesize the missing alternate.

    rows = [{
        "case": case.name, "purpose": purpose, "status": "ok", "latency_seconds": 1,
        "usage": {"output_tokens": 100}, "checks": run.evaluate_outfit(case, outfit(case)),
    } for case, purpose, _ in run.plans() if purpose == "quality"]
    affected = next(row for row in rows if row["case"] == fixture.name)
    affected["checks"] = checks
    decision = run.automatic_decision(rows)
    assert not decision["passed"]
    assert decision["counts"]["enough_alternates"] == 23

    payload["alternates"] = [{
        "item_ids": core if optional_in_primary else with_bag,
        "rationale": "An optional bag changes the item set while preserving a complete look.",
    }]
    affected["checks"] = run.evaluate_outfit(fixture, payload)
    assert all(value is not False for value in affected["checks"].values())
    assert run.automatic_decision(rows)["passed"]


def test_two_item_dress_capsule_still_allows_no_alternates():
    fixture = next(case for case in cases() if case.name == "tiny_dress")
    payload = outfit(fixture)
    assert len(fixture.request["items"]) == len(payload["item_ids"]) == 2
    assert payload["alternates"] == []
    assert fixture.minimum_alternates == 0
    assert all(value is not False for value in run.evaluate_outfit(fixture, payload).values())


def test_cost_uses_disjoint_counters_and_cache_probe_requires_read_savings():
    usage = {"input_tokens": 1000, "output_tokens": 1000,
             "cache_creation_input_tokens": 1000, "cache_read_input_tokens": 1000}
    assert run.usage_cost(usage) == Decimal("0.0147")
    assert run.usage_cost(usage, run.HAIKU_MODEL) == Decimal("0.00735")
    rows = [{"purpose": purpose, "status": "ok", "usage": usage} for purpose in (
        "cache_off", "cache_off", "cache_ephemeral", "cache_ephemeral",
    )]
    assert run.cache_decision(rows)["retain_caching"]
    usage["cache_read_input_tokens"] = 0
    assert not run.cache_decision(rows)["retain_caching"]
    assert not run.cache_decision(rows[:3])["retain_caching"]


@pytest.mark.parametrize("counter,tokens,expected", [
    ("input_tokens", 3, "0.000006"),
    ("output_tokens", 7, "0.000070"),
    ("cache_creation_input_tokens", 3, "0.0000075"),
    ("cache_read_input_tokens", 3, "0.0000006"),
])
def test_sonnet_usage_cost_preserves_fractional_rates_for_every_counter(counter, tokens, expected):
    usage = dict.fromkeys((
        "input_tokens", "output_tokens", "cache_creation_input_tokens", "cache_read_input_tokens",
    ), 0)
    usage[counter] = tokens
    assert run.usage_cost(usage, "claude-sonnet-5") == Decimal(expected)


def test_sonnet_cache_counterfactual_uses_selected_input_rate():
    usage = {"input_tokens": 1000, "output_tokens": 1000,
             "cache_creation_input_tokens": 1000, "cache_read_input_tokens": 1000}
    assert run.usage_cost(usage, "claude-sonnet-5") == Decimal("0.0147")
    rows = [{"purpose": purpose, "status": "ok", "usage": usage} for purpose in (
        "cache_off", "cache_off", "cache_ephemeral", "cache_ephemeral",
    )]
    measured = run.cache_decision(rows, "claude-sonnet-5")
    assert measured["cached_input_cost_usd"] == "0.009400"
    assert measured["uncached_counterfactual_usd"] == "0.012000"
    assert measured["retain_caching"]
    usage["cache_read_input_tokens"] = 0
    assert not run.cache_decision(rows, "claude-sonnet-5")["retain_caching"]


@pytest.mark.parametrize("model,maximum,total_cost,unit_cost", [
    ("claude-sonnet-5", "57.286720", "0.039200", "0.001400"),
    (run.HAIKU_MODEL, "5.843360", "0.019600", "0.000700"),
])
def test_fake_profile_run_is_bounded_and_uses_selected_costs(
    monkeypatch, tmp_path, model, maximum, total_cost, unit_cost,
):
    state, report, output = fake_run(monkeypatch, tmp_path, model=model)
    assert len(state["calls"]) == 28
    assert all(params["model"] == model for params in state["calls"])
    assert state["client_options"]["max_retries"] == 0
    assert state["client_options"]["timeout"] == 30
    assert state["client_options"]["base_url"] == "https://api.anthropic.com"
    assert report["complete"] and report["usage_complete"]
    assert report["automatic"]["passed"]
    assert not report["quality_accepted"]
    assert report["maximum_attempted_cost_usd"] == maximum
    assert report["known_cost_usd"] == total_cost
    assert report["known_quality_cost_per_usable_recommendation_usd"] == unit_cost
    assert report["human_review"] == "pending"
    journal = [json.loads(line) for line in (output / "accounting.jsonl").read_text().splitlines()]
    assert journal[-1]["attempted_calls"] == 28
    assert journal[-1]["maximum_attempted_cost_usd"] == maximum
    scores = json.loads((output / "scores.json").read_text())
    for row in scores:
        row.update(dict.fromkeys(run.HUMAN_DIMENSIONS, 4))
    report["rows"][0]["checks"]["complete_outfits"] = False
    decision = run.score_review(report, scores)
    assert not decision["accepted"]
    assert "Sonnet" not in decision["next_step"]
    assert "separately approved" in decision["next_step"]


def test_sonnet_live_cli_uses_explicit_profile_and_stops_on_provider_error(
    monkeypatch, tmp_path, capsys,
):
    model = "claude-sonnet-5"
    state = install_fake(monkeypatch, failure="connection")
    approved = run.manifest(model)
    output = tmp_path / "new-run"
    assert run.main([
        "live", "--model", model, "--approved-manifest-sha256", approved["manifest_sha256"],
        "--approved-max-usd", "58.00", "--output-dir", str(output),
    ]) == 2
    assert len(state["calls"]) == 1
    assert state["calls"][0]["model"] == model
    assert state["client_options"]["max_retries"] == 0
    aggregate = json.loads(capsys.readouterr().out)
    assert aggregate["maximum_attempted_cost_usd"] == "2.010240"
    report = json.loads((output / "report.json").read_text())
    assert report["manifest"]["model"] == model
    assert not report["usage_complete"]


@pytest.mark.parametrize("model", [run.HAIKU_MODEL, "claude-sonnet-5"])
@pytest.mark.parametrize("boundary", ["input", "combined_input", "output"])
def test_profile_token_boundary_stops_with_uncertain_charge_and_no_review(
    monkeypatch, tmp_path, model, boundary,
):
    state = install_fake(monkeypatch)
    profile = run.model_profile(model)
    if boundary == "input":
        state["usage"]["input_tokens"] = profile.context_limit + 1
    elif boundary == "combined_input":
        state["usage"]["input_tokens"] = profile.context_limit
        state["usage"]["cache_read_input_tokens"] = 1
    else:
        state["usage"]["output_tokens"] = run.OUTPUT_LIMIT + 1
    approved = run.manifest(model)
    output = tmp_path / "new-run"
    report = run.live_run(
        approved["manifest_sha256"], profile.approval_ceiling_usd, output, model=model,
    )
    assert len(state["calls"]) == 1
    assert not report["complete"] and not report["usage_complete"]
    assert not report["automatic"]["passed"]
    assert report["rows"][0]["status"] == "token_boundary_breach_run_stopped"
    assert "calculated_cost_usd" not in report["rows"][0]
    assert "checks" not in report["rows"][0]
    assert report["known_cost_usd"] == "0.000000"
    assert report["maximum_attempted_cost_usd"] == approved["calls"][0]["maximum_estimated_usd"]
    assert json.loads((output / "blinded-review.json").read_text())["cases"] == []


def test_sonnet_accepts_full_profile_context_above_haiku_bound(monkeypatch, tmp_path):
    model = "claude-sonnet-5"
    state = install_fake(monkeypatch)
    state["usage"]["input_tokens"] = 1_000_000
    approved = run.manifest(model)
    report = run.live_run(
        approved["manifest_sha256"], "58.00", tmp_path / "new-run", model=model,
    )
    assert len(state["calls"]) == 28
    assert report["complete"] and report["usage_complete"]
    assert report["known_cost_usd"] == "56.028000"


def test_fake_live_run_is_bounded_and_produces_blinded_packet(monkeypatch, tmp_path):
    state, report, output = fake_run(monkeypatch, tmp_path)
    assert len(state["calls"]) == 28
    assert state["client_options"]["max_retries"] == 0
    assert state["client_options"]["timeout"] == 30
    assert state["client_options"]["base_url"] == "https://api.anthropic.com"
    assert report["complete"]
    assert report["automatic"]["passed"]
    assert not report["quality_accepted"]
    assert report["human_review"] == "pending"
    assert report["maximum_attempted_cost_usd"] == "57.286720"
    assert report["known_cost_usd"] == "0.039200"
    packet = json.loads((output / "blinded-review.json").read_text())
    assert len(packet["cases"]) == 24
    assert all(set(row) == {"blind_id", "fictional_request", "outfit"} for row in packet["cases"])
    assert "claude-" not in (output / "blinded-review.json").read_text()
    assert (output / "report.json").stat().st_mode & 0o777 == 0o600
    journal_text = (output / "accounting.jsonl").read_text()
    journal = [json.loads(line) for line in journal_text.splitlines()]
    assert len(journal) == 58  # header + 28 durable reservations/settlements + final aggregate
    assert journal[-1]["event"] == "run_finished"
    assert journal[-1]["attempted_calls"] == 28
    assert journal[-1]["maximum_attempted_cost_usd"] == "57.286720"
    assert "fictional_request" not in journal_text
    assert "rationale" not in journal_text
    assert "fictional-evaluation-test-key" not in journal_text
    assert (output / "accounting.jsonl").stat().st_mode & 0o777 == 0o600
    with pytest.raises(FileExistsError):
        run.live_run(run.manifest()["manifest_sha256"], "58.00", output)
    assert len(state["calls"]) == 28


def test_provider_error_stops_run_and_reserves_uncertain_charge(monkeypatch, tmp_path):
    state, report, output = fake_run(monkeypatch, tmp_path, failure="connection")
    assert len(state["calls"]) == 1
    assert not report["complete"]
    assert not report["usage_complete"]
    assert report["known_cost_usd"] == "0.000000"
    assert report["maximum_attempted_cost_usd"] == "2.010240"
    assert report["rows"][0]["status"] == "provider_error_run_stopped"
    journal = [json.loads(line) for line in (output / "accounting.jsonl").read_text().splitlines()]
    assert journal[-2]["event"] == "attempt_finished"
    assert journal[-2]["latest_status"] == "provider_error_run_stopped"
    assert journal[-2]["maximum_attempted_cost_usd"] == "2.010240"


def test_ctrl_c_stops_after_one_uncertain_attempt_and_retains_aggregate(monkeypatch, tmp_path):
    state, report, output = fake_run(monkeypatch, tmp_path, failure="interrupt")
    assert len(state["calls"]) == 1
    assert not report["complete"]
    assert report["maximum_attempted_cost_usd"] == "2.010240"
    assert report["rows"][0]["status"] == "interrupted_run_stopped"
    journal = [json.loads(line) for line in (output / "accounting.jsonl").read_text().splitlines()]
    assert journal[-1]["latest_status"] == "interrupted_run_stopped"


def test_cli_interrupt_returns_failure_after_saving_report(monkeypatch, tmp_path, capsys):
    state = install_fake(monkeypatch, failure="interrupt")
    output = tmp_path / "new-run"
    assert run.main([
        "live", "--approved-manifest-sha256", run.manifest()["manifest_sha256"],
        "--approved-max-usd", "58.00", "--output-dir", str(output),
    ]) == 130
    assert len(state["calls"]) == 1
    assert (output / "report.json").exists()
    assert not json.loads(capsys.readouterr().out)["complete"]


def test_abrupt_exit_keeps_durable_charge_even_without_final_report(monkeypatch, tmp_path):
    with pytest.raises(SystemExit):
        fake_run(monkeypatch, tmp_path, failure="exit")
    output = tmp_path / "new-run"
    assert not (output / "report.json").exists()
    text = (output / "accounting.jsonl").read_text()
    journal = [json.loads(line) for line in text.splitlines()]
    assert journal[-1]["attempted_calls"] == 1
    assert journal[-1]["maximum_attempted_cost_usd"] == "2.010240"
    assert journal[-1]["event"] == "attempt_uncertain"
    assert "private-error-text" not in text


def test_accounting_flush_failure_blocks_provider_attempt(monkeypatch, tmp_path):
    state = install_fake(monkeypatch)
    original = run._append_accounting

    def fail_before_call(path, event, rows):
        if event == "attempt_reserved":
            raise OSError("simulated disk write failure")
        return original(path, event, rows)

    monkeypatch.setattr(run, "_append_accounting", fail_before_call)
    with pytest.raises(OSError):
        run.live_run(run.manifest()["manifest_sha256"], "58.00", tmp_path / "new-run")
    assert state["calls"] == []


def test_truncation_cannot_count_as_success_even_when_json_looks_complete(monkeypatch, tmp_path):
    _, report, _ = fake_run(monkeypatch, tmp_path, failure="truncation")
    assert not report["automatic"]["passed"]
    assert not report["complete"]
    assert report["usage_complete"]
    assert report["known_cost_usd"] == "0.039200"


def test_human_floor_cannot_be_skipped_or_pass_with_a_weak_dimension(monkeypatch, tmp_path):
    _, report, output = fake_run(monkeypatch, tmp_path)
    scores = json.loads((output / "scores.json").read_text())
    with pytest.raises(ValueError):
        run.score_review(report, scores)
    for row in scores:
        row.update(dict.fromkeys(run.HUMAN_DIMENSIONS, 4))
    assert run.score_review(report, scores)["accepted"]
    scores[0]["wearability"] = 2
    assert not run.score_review(report, scores)["accepted"]
    scores[0]["wearability"] = 4
    for row in scores:
        row["cohesion"] = 3
    assert not run.score_review(report, scores)["accepted"]
    with pytest.raises(ValueError):
        run.score_review(report, scores[:-1] + [scores[0]])


def test_automatic_floor_recomputed_during_scoring_and_p95_is_enforced(monkeypatch, tmp_path):
    _, report, output = fake_run(monkeypatch, tmp_path)
    scores = json.loads((output / "scores.json").read_text())
    for row in scores:
        row.update(dict.fromkeys(run.HUMAN_DIMENSIONS, 5))
    report["rows"][0]["checks"]["known_ids"] = False
    assert not run.score_review(report, scores)["accepted"]
    report["rows"][0]["checks"]["known_ids"] = True
    report["rows"][0]["latency_seconds"] = 21
    report["rows"][1]["latency_seconds"] = 22
    assert not run.score_review(report, scores)["accepted"]
