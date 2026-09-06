"""The acceptance workflow's safety/cost/quality gates use fictional SDK responses only."""

import json
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
    state: dict[str, Any] = {"calls": [], "client_options": {}}

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
            fixture, _, _ = run.plans()[index]
            return SimpleNamespace(
                stop_reason="max_tokens" if failure == "truncation" else "tool_use",
                content=[ToolUseBlock(type="tool_use", id="fake", name="propose_outfit",
                                      input=outfit(fixture))],
                usage=SimpleNamespace(input_tokens=200, output_tokens=100,
                                      cache_creation_input_tokens=0, cache_read_input_tokens=0),
            )

    monkeypatch.setattr(run.anthropic, "Anthropic", Client)
    monkeypatch.setenv("EVAL_ANTHROPIC_API_KEY", "fictional-evaluation-test-key")
    return state


def fake_run(monkeypatch: pytest.MonkeyPatch, tmp_path: Path, **kwargs: Any):
    state = install_fake(monkeypatch, **kwargs)
    output = tmp_path / "new-run"
    state["journal_path"] = output / "accounting.jsonl"
    report = run.live_run(run.manifest()["manifest_sha256"], "6.00", output)
    return state, report, output


def test_default_command_never_constructs_client(monkeypatch, capsys):
    def forbidden(**kwargs):
        pytest.fail("An offline dry run must not construct an API client.")

    monkeypatch.setattr(run.anthropic, "Anthropic", forbidden)
    assert run.main([]) == 0
    manifest = json.loads(capsys.readouterr().out)
    assert manifest["maximum_calls"] == 28
    assert manifest["maximum_estimated_usd"] == "5.843360"
    assert manifest["approval_ceiling_usd"] == "6.00"
    assert manifest["max_output_tokens_per_call"] == 1024
    assert manifest["maximum_calls"] == len(manifest["calls"])
    assert len({row["case"] for row in manifest["calls"]}) == 12


def test_plan_uses_exact_production_builder_without_thinking_or_retries():
    assert run.manifest() == run.manifest()
    for _, _, params in run.plans():
        assert params["model"] == "claude-haiku-4-5-20251001"
        assert params["thinking"] == {"type": "disabled"}
        assert params["max_tokens"] == 1024
        assert params["tools"][0]["strict"] is True
        assert params["tool_choice"]["name"] == "propose_outfit"


@pytest.mark.parametrize("relative_path", [
    "app/schemas/recommendation.py", "uv.lock", "pyproject.toml",
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


def test_real_sdk_transport_uses_only_explicit_eval_key_and_standard_tier(monkeypatch, tmp_path):
    real_client = anthropic.Anthropic
    observed = []
    plan = run.plans()
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
        assert body["model"] == run.PINNED_MODEL
        assert body["thinking"] == {"type": "disabled"}
        fixture, _, _ = plan[len(observed)]
        observed.append(body)
        return httpx2.Response(200, json={
            "id": "msg_fictional", "type": "message", "role": "assistant",
            "model": run.PINNED_MODEL, "stop_reason": "tool_use", "stop_sequence": None,
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
    report = run.live_run(run.manifest()["manifest_sha256"], "6.00", tmp_path / "new-run")
    assert len(observed) == 28
    assert report["complete"]
    assert report["automatic"]["passed"]


@pytest.mark.parametrize("bad_hash,bad_budget", [("wrong", "6.00"), (None, "7.00"), (None, "6")])
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
        run.live_run(run.manifest()["manifest_sha256"], "6.00", tmp_path / "unused")


@pytest.mark.parametrize("maximum", ["6.000001", "7", "NaN", "Infinity", "0", "-1"])
def test_hash_cannot_bypass_independent_numeric_cost_ceiling(monkeypatch, tmp_path, maximum):
    approved = run.manifest()
    approved["maximum_estimated_usd"] = maximum
    monkeypatch.setattr(run, "manifest", lambda: approved)

    def forbidden(**kwargs):
        pytest.fail("Cost must fit the approval before client construction.")

    monkeypatch.setattr(run.anthropic, "Anthropic", forbidden)
    with pytest.raises(ValueError, match="approval ceiling"):
        run.live_run(approved["manifest_sha256"], "6.00", tmp_path / "unused")
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


def test_raw_occasion_recent_wear_and_rating_regressions_fail():
    fixtures = {case.name: case for case in cases()}
    payload = outfit(fixtures["office"])
    payload["item_ids"] = [catalog_id(i) for i in ("t1", "b1", "s3")]
    assert not run.evaluate_outfit(fixtures["office"], payload)["occasion_constraints"]
    assert not run.evaluate_outfit(fixtures["recent_rotation"], payload)["avoid_primary"]
    assert not run.evaluate_outfit(fixtures["positive_preference"], payload)["prefer_primary"]


def test_cost_uses_disjoint_counters_and_cache_probe_requires_read_savings():
    usage = {"input_tokens": 1000, "output_tokens": 1000,
             "cache_creation_input_tokens": 1000, "cache_read_input_tokens": 1000}
    assert run.usage_cost(usage) == Decimal("0.00735")
    rows = [{"purpose": purpose, "status": "ok", "usage": usage} for purpose in (
        "cache_off", "cache_off", "cache_ephemeral", "cache_ephemeral",
    )]
    assert run.cache_decision(rows)["retain_caching"]
    usage["cache_read_input_tokens"] = 0
    assert not run.cache_decision(rows)["retain_caching"]
    assert not run.cache_decision(rows[:3])["retain_caching"]


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
    assert report["maximum_attempted_cost_usd"] == "5.843360"
    assert report["known_cost_usd"] == "0.019600"
    packet = json.loads((output / "blinded-review.json").read_text())
    assert len(packet["cases"]) == 24
    assert all(set(row) == {"blind_id", "fictional_request", "outfit"} for row in packet["cases"])
    assert "claude-haiku" not in (output / "blinded-review.json").read_text()
    assert (output / "report.json").stat().st_mode & 0o777 == 0o600
    journal_text = (output / "accounting.jsonl").read_text()
    journal = [json.loads(line) for line in journal_text.splitlines()]
    assert len(journal) == 58  # header + 28 durable reservations/settlements + final aggregate
    assert journal[-1]["event"] == "run_finished"
    assert journal[-1]["attempted_calls"] == 28
    assert journal[-1]["maximum_attempted_cost_usd"] == "5.843360"
    assert "fictional_request" not in journal_text
    assert "rationale" not in journal_text
    assert "fictional-evaluation-test-key" not in journal_text
    assert (output / "accounting.jsonl").stat().st_mode & 0o777 == 0o600
    with pytest.raises(FileExistsError):
        run.live_run(run.manifest()["manifest_sha256"], "6.00", output)
    assert len(state["calls"]) == 28


def test_provider_error_stops_run_and_reserves_uncertain_charge(monkeypatch, tmp_path):
    state, report, output = fake_run(monkeypatch, tmp_path, failure="connection")
    assert len(state["calls"]) == 1
    assert not report["complete"]
    assert not report["usage_complete"]
    assert report["known_cost_usd"] == "0.000000"
    assert report["maximum_attempted_cost_usd"] == "0.205120"
    assert report["rows"][0]["status"] == "provider_error_run_stopped"
    journal = [json.loads(line) for line in (output / "accounting.jsonl").read_text().splitlines()]
    assert journal[-2]["event"] == "attempt_finished"
    assert journal[-2]["latest_status"] == "provider_error_run_stopped"
    assert journal[-2]["maximum_attempted_cost_usd"] == "0.205120"


def test_ctrl_c_stops_after_one_uncertain_attempt_and_retains_aggregate(monkeypatch, tmp_path):
    state, report, output = fake_run(monkeypatch, tmp_path, failure="interrupt")
    assert len(state["calls"]) == 1
    assert not report["complete"]
    assert report["maximum_attempted_cost_usd"] == "0.205120"
    assert report["rows"][0]["status"] == "interrupted_run_stopped"
    journal = [json.loads(line) for line in (output / "accounting.jsonl").read_text().splitlines()]
    assert journal[-1]["latest_status"] == "interrupted_run_stopped"


def test_cli_interrupt_returns_failure_after_saving_report(monkeypatch, tmp_path, capsys):
    state = install_fake(monkeypatch, failure="interrupt")
    output = tmp_path / "new-run"
    assert run.main([
        "live", "--approved-manifest-sha256", run.manifest()["manifest_sha256"],
        "--approved-max-usd", "6.00", "--output-dir", str(output),
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
    assert journal[-1]["maximum_attempted_cost_usd"] == "0.205120"
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
        run.live_run(run.manifest()["manifest_sha256"], "6.00", tmp_path / "new-run")
    assert state["calls"] == []


def test_truncation_cannot_count_as_success_even_when_json_looks_complete(monkeypatch, tmp_path):
    _, report, _ = fake_run(monkeypatch, tmp_path, failure="truncation")
    assert not report["automatic"]["passed"]
    assert not report["complete"]
    assert report["usage_complete"]
    assert report["known_cost_usd"] == "0.019600"


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
