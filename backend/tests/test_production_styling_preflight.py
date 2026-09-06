"""Budget preflight stays read-only and rejects missing or untrusted remote state."""

import base64
import json
import re

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
    "model": "pinned-haiku",
    "policy": "bounded",
    "ledger": "ready",
    "spend_band": "below-warning",
    "enabled": "yes",
    "concurrency": "clear",
}


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
    assert argv[:9] == [
        "flyctl", "ssh", "console", "--app", APP,
        "--machine", MACHINE, "--quiet", "--command",
    ]
    assert timeout == 45
    encoded = re.search(r"b64decode\('([^']+)'\)", argv[-1]).group(1)
    script = base64.b64decode(encoded).decode()
    assert "production_styling_status()" in script
    assert "sqlite3.connect" not in script
    assert "messages.create" not in script
    assert "styling_budget" in MODULE.CHECK_ORDER


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


@pytest.mark.parametrize("value", [
    {}, {"unavailable": True},
    READY | {"model": "claude-opus-4-8"},
    READY | {"policy": "unbounded"},
    READY | {"ledger": "missing"},
    READY | {"spend_band": ["below-warning"]},
    READY | {"private_monthly_limit": SECRET_CANARY},
    READY | {"spend_band": SECRET_CANARY},
    [READY],
])
def test_old_runtime_or_untrusted_diagnostic_fails_closed_and_redacts(value):
    runtime, _ = valid_runtime()
    result = MODULE.check_styling_budget(BudgetRunner(value), runtime=runtime)
    assert result == MODULE._open("styling_budget", "styling-budget-evidence-open")
    results = tuple(
        result if name == "styling_budget" else MODULE._pass(name, MODULE._PASS_DETAILS[name])
        for name in MODULE.CHECK_ORDER
    )
    report = MODULE.ReviewReport(checked_at=NOW, results=results)
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
