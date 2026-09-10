"""Budget preflight stays read-only and rejects missing or untrusted remote state."""

import base64
import json
import os
import re
import sys
from types import ModuleType

import pytest

from tests.test_verify_production_operations import (
    APP,
    MACHINE,
    MODULE,
    NOW,
    SECRET_CANARY,
    FakeRunner,
    valid_runtime,
)

READY = {
    "model": "pinned-sonnet",
    "policy": "bounded",
    "ledger": "ready",
    "spend_band": "below-warning",
    "enabled": "yes",
    "concurrency": "clear",
}


def report_with_budget(result, *, purpose=MODULE.ReviewPurpose.AI_LAUNCH):
    return MODULE.ReviewReport(
        checked_at=NOW,
        results=tuple(
            result if name == "styling_budget" else MODULE._pass(name, MODULE._PASS_DETAILS[name])
            for name in MODULE.CHECK_ORDER
        ),
        purpose=purpose,
    )


class BudgetRunner:
    def __init__(self, value=None, *, returncode=0, timed_out=False):
        self.value = READY if value is None else value
        self.returncode = returncode
        self.timed_out = timed_out
        self.calls = []

    def run(self, argv, *, timeout):
        self.calls.append((argv, timeout))
        return MODULE.CommandOutput(
            returncode=self.returncode,
            timed_out=self.timed_out,
            stdout="Provider banner\n" + json.dumps(self.value),
            stderr=SECRET_CANARY,
        )


def test_preflight_requires_new_runtime_budget_check_without_printing_limits():
    runtime, _ = valid_runtime()
    runner = BudgetRunner()
    result = MODULE.check_styling_budget(runner, runtime=runtime)

    assert result == MODULE._pass("styling_budget", "bounded-enabled-below-warning")
    argv, timeout = runner.calls[0]
    assert argv[:11] == [
        "flyctl", "ssh", "console", "--app", APP,
        "--machine", MACHINE, "--user", "wardrobe", "--quiet", "--command",
    ]
    assert timeout == 45
    encoded = re.search(r"b64decode\('([^']+)'\)", argv[-1]).group(1)
    script = base64.b64decode(encoded).decode()
    assert "production_styling_status()" in script
    assert "sqlite3.connect" not in script
    assert "messages.create" not in script
    assert "styling_budget" in MODULE.CHECK_ORDER


@pytest.mark.parametrize("identity", [
    (10001, 10001, 10001, 10001),
    (0, 0, 0, 0),
    (0, 10001, 10001, 10001),
    (10001, 0, 10001, 10001),
    (10001, 10001, 0, 10001),
    (10001, 10001, 10001, 0),
])
def test_remote_budget_probe_checks_service_identity_before_reading_ledger(
    monkeypatch, capsys, identity,
):
    calls = []
    runtime_module = ModuleType("app.styling_runtime")

    def status():
        calls.append("read-only-status")
        return READY

    runtime_module.production_styling_status = status
    monkeypatch.setitem(sys.modules, "app.styling_runtime", runtime_module)
    for name, value in zip(("getuid", "geteuid", "getgid", "getegid"), identity, strict=True):
        monkeypatch.setattr(os, name, lambda value=value: value)

    exec(compile(MODULE._REMOTE_STYLING_DIAGNOSTIC, "<budget-probe>", "exec"), {})

    emitted = json.loads(capsys.readouterr().out)
    if identity == (10001,) * 4:
        assert calls == ["read-only-status"]
        assert emitted == READY
    else:
        assert calls == []
        assert emitted == {"unavailable": True}


def test_remote_budget_probe_redacts_service_read_failure(monkeypatch, capsys):
    runtime_module = ModuleType("app.styling_runtime")

    def status():
        raise PermissionError(SECRET_CANARY)

    runtime_module.production_styling_status = status
    monkeypatch.setitem(sys.modules, "app.styling_runtime", runtime_module)
    for name in ("getuid", "geteuid", "getgid", "getegid"):
        monkeypatch.setattr(os, name, lambda: 10001)

    exec(compile(MODULE._REMOTE_STYLING_DIAGNOSTIC, "<budget-probe>", "exec"), {})

    captured = capsys.readouterr()
    assert json.loads(captured.out) == {"unavailable": True}
    assert SECRET_CANARY not in captured.out + captured.err


@pytest.mark.parametrize("changes, detail, expected_status", [
    ({"spend_band": "warning"}, "spend-warning", MODULE.Status.WARNING),
    ({"spend_band": "critical"}, "spend-critical", MODULE.Status.WARNING),
    ({"spend_band": "exhausted"}, "spend-exhausted", MODULE.Status.OPEN),
    ({"enabled": "no"}, "styling-disabled", MODULE.Status.OPEN),
    ({"concurrency": "pending"}, "requests-pending", MODULE.Status.OPEN),
])
def test_budget_bands_and_disabled_or_pending_state_block_preflight(
    changes, detail, expected_status,
):
    runtime, _ = valid_runtime()
    result = MODULE.check_styling_budget(BudgetRunner(READY | changes), runtime=runtime)
    assert result.detail == detail
    assert result.status is expected_status


@pytest.mark.parametrize("changes, detail, expected_status", [
    ({"spend_band": "warning"}, "spend-warning", MODULE.Status.WARNING),
    ({"spend_band": "critical"}, "spend-critical", MODULE.Status.WARNING),
    ({"spend_band": "exhausted"}, "spend-exhausted", MODULE.Status.OPEN),
    ({"concurrency": "pending"}, "requests-pending", MODULE.Status.OPEN),
    (
        {"spend_band": "warning", "concurrency": "pending"},
        "spend-warning", MODULE.Status.WARNING,
    ),
])
def test_disabled_styling_never_masks_adverse_budget_state(changes, detail, expected_status):
    runtime, _ = valid_runtime()
    result = MODULE.check_styling_budget(
        BudgetRunner(READY | {"enabled": "no"} | changes), runtime=runtime,
    )
    assert result == MODULE.CheckResult("styling_budget", expected_status, detail)
    for purpose in MODULE.ReviewPurpose:
        assert report_with_budget(result, purpose=purpose).passed is False


def test_verified_disabled_budget_is_eligible_only_for_explicit_internal_beta():
    runtime, _ = valid_runtime()
    result = MODULE.check_styling_budget(BudgetRunner(READY | {"enabled": "no"}), runtime=runtime)
    default_report = report_with_budget(result)
    beta_report = report_with_budget(
        result, purpose=MODULE.ReviewPurpose.INTERNAL_BETA_AI_DISABLED,
    )

    assert default_report.purpose is MODULE.ReviewPurpose.AI_LAUNCH
    assert default_report.passed is False
    assert beta_report.passed is True
    assert beta_report.results == default_report.results
    assert "styling_budget=OPEN styling-disabled" in beta_report.render()
    assert "review_purpose=internal-beta-ai-disabled" in beta_report.render()
    assert (
        "preupload_evidence=PASS_INTERNAL_BETA_ONLY owner-upload-approval-still-required"
        in beta_report.render()
    )
    assert "preupload_evidence=PASS " not in beta_report.render()
    assert json.dumps({"purpose": beta_report.purpose}) == (
        '{"purpose": "internal-beta-ai-disabled"}'
    )


def test_enabled_budget_does_not_match_disabled_beta_purpose():
    runtime, _ = valid_runtime()
    result = MODULE.check_styling_budget(BudgetRunner(), runtime=runtime)
    assert report_with_budget(result).passed is True
    report = report_with_budget(result, purpose=MODULE.ReviewPurpose.INTERNAL_BETA_AI_DISABLED)
    assert report.passed is False
    assert "styling_budget=PASS bounded-enabled-below-warning" in report.render()
    assert "preupload_evidence=OPEN" in report.render()


@pytest.mark.parametrize("name, detail, status", [
    (name, detail, MODULE.Status.WARNING if (name, detail) in MODULE._WARNING_RESULTS
     else MODULE.Status.OPEN)
    for name, details in MODULE._DETAILS.items()
    if name != "styling_budget"
    for detail in sorted(details)
    if detail != MODULE._PASS_DETAILS[name]
    and (name, detail) not in MODULE._ADDITIONAL_PASS_RESULTS
])
def test_disabled_beta_does_not_relax_any_other_open_or_warning_check(name, detail, status):
    budget = MODULE._open("styling_budget", "styling-disabled")
    otherwise_ready = report_with_budget(
        budget, purpose=MODULE.ReviewPurpose.INTERNAL_BETA_AI_DISABLED,
    )
    results = tuple(
        MODULE.CheckResult(name, status, detail) if result.name == name else result
        for result in otherwise_ready.results
    )
    for purpose in MODULE.ReviewPurpose:
        report = MODULE.ReviewReport(checked_at=NOW, results=results, purpose=purpose)
        assert report.passed is False
        assert "preupload_evidence=OPEN" in report.render()


@pytest.mark.parametrize("alteration", ["missing", "duplicate", "reordered"])
def test_disabled_beta_requires_complete_unique_ordered_checks(alteration):
    report = report_with_budget(
        MODULE._open("styling_budget", "styling-disabled"),
        purpose=MODULE.ReviewPurpose.INTERNAL_BETA_AI_DISABLED,
    )
    if alteration == "missing":
        results = report.results[1:]
    elif alteration == "duplicate":
        results = (report.results[0], *report.results)
    else:
        results = tuple(reversed(report.results))
    malformed = MODULE.ReviewReport(checked_at=NOW, results=results, purpose=report.purpose)
    assert malformed.passed is False


@pytest.mark.parametrize("purpose", [None, SECRET_CANARY, "internal-beta-ai-disabled", True])
def test_report_rejects_unvalidated_purpose_without_rendering_it(purpose):
    with pytest.raises(MODULE.ReviewConfigurationError, match="^review purpose is invalid$"):
        report_with_budget(
            MODULE._open("styling_budget", "styling-disabled"), purpose=purpose,
        )


@pytest.mark.parametrize("value", [
    {}, {"unavailable": True},
    READY | {"model": "pinned-haiku"},
    READY | {"model": "claude-opus-4-8"},
    READY | {"policy": "unbounded"},
    READY | {"ledger": "missing"},
    READY | {"enabled": "no", "ledger": "corrupt"},
    READY | {"enabled": "no", "policy": "unbounded"},
    READY | {"enabled": "no", "concurrency": "unknown"},
    READY | {"enabled": False},
    {key: value for key, value in (READY | {"enabled": "no"}).items() if key != "ledger"},
    READY | {"spend_band": ["below-warning"]},
    READY | {"private_monthly_limit": SECRET_CANARY},
    READY | {"spend_band": SECRET_CANARY},
    [READY],
])
def test_old_runtime_or_untrusted_diagnostic_fails_closed_and_redacts(value):
    runtime, _ = valid_runtime()
    result = MODULE.check_styling_budget(BudgetRunner(value), runtime=runtime)
    assert result == MODULE._open("styling_budget", "styling-budget-evidence-open")
    for purpose in MODULE.ReviewPurpose:
        report = report_with_budget(result, purpose=purpose)
        assert report.passed is False
        assert SECRET_CANARY not in report.render()


@pytest.mark.parametrize("options", [{"returncode": 1}, {"timed_out": True}])
def test_failed_or_timed_out_diagnostic_cannot_pass(options):
    runtime, _ = valid_runtime()
    result = MODULE.check_styling_budget(BudgetRunner(**options), runtime=runtime)
    assert result.status is MODULE.Status.OPEN


def test_no_verified_runtime_skips_remote_probe():
    runner = BudgetRunner()
    result = MODULE.check_styling_budget(runner, runtime=None)
    assert result.status is MODULE.Status.OPEN
    assert not runner.calls


def test_budget_failure_cluster_blocks_bounded_event_review():
    events = [
        {"timestamp": MODULE._format_utc(NOW), "message": "styling_budget_event code=" + code}
        for code in ("store_unavailable", "admission_closed", "settlement_failed")
    ]
    runner = FakeRunner({
        ("flyctl", "logs", "--no-tail", "--json", "--app", APP): "\n".join(
            json.dumps(event) for event in events
        ),
    })
    result = MODULE.check_bounded_events(runner, app=APP, now=NOW)
    assert result == MODULE._open("bounded_events", "failure-cluster-open")
