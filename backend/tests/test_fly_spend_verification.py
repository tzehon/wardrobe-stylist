"""Local evidence consistency cannot stand in for live billing or monitor acceptance."""

import copy
import json
import os
from datetime import UTC, datetime

import pytest

import verify_fly_spend as spend

NOW = datetime(2026, 7, 12, 12, tzinfo=UTC)
POLICY_REVISION = "a" * 64
SOURCE_REVISION = "b" * 64
CANARY = "private-canary-never-output"


def documents():
    envelope = {
        "organization": CANARY,
        "apps": ["fixture-app"],
        "machines": [{
            "id": "fixture-machine", "app": "fixture-app", "region": "fixture-region",
            "cpu_kind": "shared", "cpu_count": 1, "memory_mb": 256,
            "image_revision": "fixture-image", "volume_ids": ["fixture-volume"],
            "state": "started",
        }],
        "volumes": [{
            "id": "fixture-volume", "app": "fixture-app", "region": "fixture-region",
            "size_gb": 1, "encrypted": True, "snapshot_retention_days": 14,
            "automatic_snapshots": True,
        }],
        "ips": [{"id": "fixture-ip", "app": "fixture-app", "kind": "shared_v4"}],
        "services": [],
        "linked_organizations": [],
    }
    policy = {
        "schema_version": 1, "policy_revision": POLICY_REVISION,
        "currency": "USD", "unit": "millionth_usd",
        "warning_units": 150_000_000, "hold_units": 250_000_000,
        "operating_target_units": 500_000_000,
        "resource_max_age_seconds": 3600, "billing_observation_max_age_seconds": 3600,
        "billing_coverage_max_age_seconds": 3600, "expected": envelope,
    }
    resources = {
        "schema_version": 1, "policy_revision": POLICY_REVISION,
        "source": "flyctl_and_console_manual_v1", "source_revision": SOURCE_REVISION,
        "observed_at": "2026-07-12T11:55:00Z",
        "inventory_coverage": sorted(spend.REQUIRED_COVERAGE),
        "envelope": copy.deepcopy(envelope),
    }
    view = {
        "source_revision": SOURCE_REVISION, "observed_at": "2026-07-12T11:55:00Z",
        "pretax_consumption_units": 100_000_000, "net_payable_units": 0,
        "coverage_starts_at": "2026-07-01T00:00:00Z",
        "coverage_ends_at": "2026-07-12T11:50:00Z",
    }
    billing = {
        "schema_version": 1, "policy_revision": POLICY_REVISION,
        "currency": "USD", "unit": "millionth_usd",
        "period_starts_at": "2026-07-01T00:00:00Z",
        "period_ends_at": "2026-08-01T00:00:00Z",
        "invoice": view | {"source": "fly_invoice_preview_manual_v1"},
        "cost_explorer": view | {"source": "fly_cost_explorer_manual_v1"},
    }
    return policy, resources, billing


def evaluate(policy, resources, billing):
    return spend.assess(policy, resources, billing, now=NOW)


def write_private(path, value):
    path.write_text(json.dumps(value))
    path.chmod(0o600)
    return path


def test_consistent_supplied_evidence_does_not_claim_live_readiness_or_authority():
    result = evaluate(*documents())
    assert result == {
        "scope": "LOCAL_EVIDENCE_ONLY", "assessment": "CONSISTENT_LOCAL_EVIDENCE",
        "resources": "CONSISTENT", "billing": "CONSISTENT",
        "observed_consumption": "NO_OBSERVED_THRESHOLD_CROSSING",
        "forecast": "NOT_ASSESSED", "live_provenance": "NOT_VERIFIED",
        "activation_authority": "NONE", "hold_execution": "NOT_PERFORMED",
        "reason_codes": [],
    }
    assert CANARY not in json.dumps(result)
    assert POLICY_REVISION not in json.dumps(result)
    assert "150000000" not in json.dumps(result)


@pytest.mark.parametrize("which", ["invoice", "cost_explorer"])
@pytest.mark.parametrize("amount, expected", [
    (149_999_999, "UNKNOWN"), (150_000_000, "WARNING"),
    (249_999_999, "WARNING"), (250_000_000, "HOLD_REQUIRED"),
])
def test_adverse_consumption_survives_unknown_coverage_and_unreconciled_totals(
    which, amount, expected,
):
    policy, resources, billing = documents()
    billing[which]["pretax_consumption_units"] = amount
    billing[which]["coverage_ends_at"] = None
    result = evaluate(policy, resources, billing)
    assert result["assessment"] == "OPEN"
    assert result["billing"] == "OPEN"
    assert result["observed_consumption"] == expected
    assert "BILLING_TOTALS_UNRECONCILED" in result["reason_codes"]
    assert "BILLING_COVERAGE_UNKNOWN" in result["reason_codes"]


@pytest.mark.parametrize("missing", ["invoice", "cost_explorer"])
def test_known_warning_survives_other_view_missing_pretax_consumption(missing):
    policy, resources, billing = documents()
    for name in ("invoice", "cost_explorer"):
        billing[name]["pretax_consumption_units"] = policy["warning_units"]
    billing[missing]["pretax_consumption_units"] = None
    result = evaluate(policy, resources, billing)
    assert result["observed_consumption"] == "WARNING"
    assert result["reason_codes"] == ["BILLING_PRETAX_CONSUMPTION_MISSING"]


def test_net_payable_and_credit_waivers_cannot_hide_consumption_or_create_fake_consumption():
    policy, resources, billing = documents()
    for view in (billing["invoice"], billing["cost_explorer"]):
        view["pretax_consumption_units"] = policy["hold_units"]
        view["net_payable_units"] = 0
    assert evaluate(policy, resources, billing)["observed_consumption"] == "HOLD_REQUIRED"
    for view in (billing["invoice"], billing["cost_explorer"]):
        view["pretax_consumption_units"] = None
        view["net_payable_units"] = policy["hold_units"]
    result = evaluate(policy, resources, billing)
    assert result["observed_consumption"] == "UNKNOWN"
    assert result["billing"] == "OPEN"


@pytest.mark.parametrize("changes, reason", [
    ({"coverage_ends_at": None}, "BILLING_COVERAGE_UNKNOWN"),
    ({"coverage_starts_at": None}, "BILLING_COVERAGE_UNKNOWN"),
    ({"coverage_starts_at": "2026-07-02T00:00:00Z"}, "BILLING_COVERAGE_INCOMPLETE"),
    ({"coverage_ends_at": "2026-07-12T10:59:59Z"}, "BILLING_COVERAGE_STALE"),
    ({"observed_at": "2026-07-12T10:59:59Z", "coverage_ends_at": "2026-07-12T10:50:00Z"},
     "BILLING_OBSERVATION_STALE"),
])
def test_observation_time_cannot_replace_missing_or_stale_coverage(changes, reason):
    policy, resources, billing = documents()
    for view in (billing["invoice"], billing["cost_explorer"]):
        view.update(changes)
        view["pretax_consumption_units"] = policy["hold_units"]
    result = evaluate(policy, resources, billing)
    assert reason in result["reason_codes"]
    assert result["billing"] == "OPEN"
    assert result["observed_consumption"] == "HOLD_REQUIRED"


def test_equal_totals_with_different_coverage_are_unreconciled():
    policy, resources, billing = documents()
    billing["cost_explorer"]["coverage_ends_at"] = "2026-07-12T11:49:00Z"
    result = evaluate(policy, resources, billing)
    assert result["reason_codes"] == ["BILLING_COVERAGE_UNRECONCILED"]
    assert result["observed_consumption"] == "UNKNOWN"


@pytest.mark.parametrize("key, value", [
    ("source", "unreviewed-source"), ("source_revision", "not-a-revision"),
    ("fresh", True), ("coverage_ends_at", ""),
    ("coverage_ends_at", "2026-07-12T12:00:00Z"),
    ("coverage_ends_at", "2026-07-12T19:50:00+08:00"),
    ("coverage_ends_at", "2026-07-12T11:50:00"),
    ("coverage_starts_at", "2026-07-12T11:51:00Z"),
    ("observed_at", "2026-07-12T12:00:01Z"),
    ("pretax_consumption_units", True), ("pretax_consumption_units", 1.5),
    ("pretax_consumption_units", "250000000"), ("pretax_consumption_units", -1),
    ("pretax_consumption_units", spend.MAX_INTEGER + 1),
    ("pretax_consumption_units", float("nan")),
    ("net_payable_units", float("inf")),
])
def test_invalid_view_is_not_salvaged_or_echoed(key, value):
    policy, resources, billing = documents()
    billing["invoice"][key] = value
    result = evaluate(policy, resources, billing)
    assert result["reason_codes"] == ["BILLING_EVIDENCE_INVALID"]
    assert result["observed_consumption"] == "UNKNOWN"
    assert CANARY not in json.dumps(result)


@pytest.mark.parametrize("document_index, reason", [
    (1, "RESOURCE_POLICY_REVISION_MISMATCH"), (2, "BILLING_POLICY_REVISION_MISMATCH"),
])
def test_evidence_must_be_bound_to_the_selected_policy(document_index, reason):
    values = list(documents())
    values[document_index]["policy_revision"] = "c" * 64
    assert reason in evaluate(*values)["reason_codes"]


@pytest.mark.parametrize("field, value", [
    ("schema_version", True), ("warning_units", True),
    ("warning_units", 0), ("warning_units", 250_000_000),
    ("hold_units", 500_000_000), ("currency", "SGD"),
    ("resource_max_age_seconds", False), ("billing_coverage_max_age_seconds", 0),
    ("policy_revision", ""), ("unapproved_field", CANARY),
])
def test_invalid_policy_cannot_produce_a_budget_assessment(field, value):
    policy, resources, billing = documents()
    policy[field] = value
    assert evaluate(policy, resources, billing)["reason_codes"] == ["POLICY_INVALID"]


@pytest.mark.parametrize("changes", [
    {"period_starts_at": "2026-06-01T00:00:00Z"},
    {"period_starts_at": "2026-07-02T00:00:00Z"},
    {"period_ends_at": "2026-07-31T00:00:00Z"},
])
def test_previous_or_partial_month_is_not_current_month_evidence(changes):
    policy, resources, billing = documents()
    billing.update(changes)
    assert evaluate(policy, resources, billing)["reason_codes"] == ["BILLING_PERIOD_NOT_CURRENT"]


def test_december_month_boundary_is_validated():
    policy, resources, billing = documents()
    resources["observed_at"] = "2026-12-12T11:55:00Z"
    billing["period_starts_at"] = "2026-12-01T00:00:00Z"
    billing["period_ends_at"] = "2027-01-01T00:00:00Z"
    for view in (billing["invoice"], billing["cost_explorer"]):
        view["observed_at"] = "2026-12-12T11:55:00Z"
        view["coverage_starts_at"] = "2026-12-01T00:00:00Z"
        view["coverage_ends_at"] = "2026-12-12T11:50:00Z"
    result = spend.assess(policy, resources, billing, now=datetime(2026, 12, 12, 12, tzinfo=UTC))
    assert result["assessment"] == "CONSISTENT_LOCAL_EVIDENCE"


@pytest.mark.parametrize("collection, row", [
    ("apps", "unexpected-builder"),
    ("machines", {"id": "stopped-extra", "app": "fixture-app", "region": "fixture-region",
                  "cpu_kind": "shared", "cpu_count": 1, "memory_mb": 256,
                  "image_revision": "fixture-image", "volume_ids": [], "state": "stopped"}),
    ("volumes", {"id": "detached-extra", "app": "fixture-app", "region": "fixture-region",
                 "size_gb": 1, "encrypted": True, "snapshot_retention_days": 14,
                 "automatic_snapshots": True}),
    ("ips", {"id": "paid-extra", "app": "fixture-app", "kind": "dedicated_v4"}),
    ("services", {"id": "extra-service", "kind": "managed_database"}),
    ("linked_organizations", "extra-organization"),
])
def test_every_extra_resource_type_is_detected(collection, row):
    policy, resources, billing = documents()
    resources["envelope"][collection].append(row)
    result = evaluate(policy, resources, billing)
    assert result["resources"] == "OPEN"
    assert "RESOURCE_ENVELOPE_MISMATCH" in result["reason_codes"]


@pytest.mark.parametrize("target, field, value", [
    ("machines", "memory_mb", 512), ("machines", "region", "another-region"),
    ("machines", "state", "stopped"), ("volumes", "size_gb", 2),
    ("volumes", "snapshot_retention_days", 1), ("volumes", "automatic_snapshots", False),
])
def test_changed_resource_configuration_is_detected(target, field, value):
    policy, resources, billing = documents()
    resources["envelope"][target][0][field] = value
    assert "RESOURCE_ENVELOPE_MISMATCH" in evaluate(policy, resources, billing)["reason_codes"]


def test_resource_mismatch_is_preserved_alongside_stale_incomplete_evidence():
    policy, resources, billing = documents()
    resources["envelope"]["services"].append({"kind": "support", "id": "unexpected"})
    resources["inventory_coverage"].remove("services")
    resources["observed_at"] = "2026-07-12T10:00:00Z"
    assert evaluate(policy, resources, billing)["reason_codes"] == [
        "RESOURCE_ENVELOPE_MISMATCH", "RESOURCE_COVERAGE_INCOMPLETE", "RESOURCE_EVIDENCE_STALE",
    ]


@pytest.mark.parametrize("collection", ["apps", "machines", "volumes", "ips"])
def test_duplicate_resource_identity_is_invalid(collection):
    policy, resources, billing = documents()
    resources["envelope"][collection] *= 2
    assert evaluate(policy, resources, billing)["reason_codes"] == ["RESOURCE_EVIDENCE_INVALID"]


def test_duplicate_unknown_and_cross_app_volume_mounts_are_invalid():
    for ids in (["fixture-volume", "fixture-volume"], ["unknown-volume"]):
        policy, resources, billing = documents()
        resources["envelope"]["machines"][0]["volume_ids"] = ids
        assert evaluate(policy, resources, billing)["reason_codes"] == ["RESOURCE_EVIDENCE_INVALID"]
    policy, resources, billing = documents()
    resources["envelope"]["apps"].append("another-app")
    resources["envelope"]["volumes"][0]["app"] = "another-app"
    assert evaluate(policy, resources, billing)["reason_codes"] == ["RESOURCE_EVIDENCE_INVALID"]


def test_resource_order_does_not_create_drift():
    policy, resources, billing = documents()
    extra = {"id": "other-ip", "app": "fixture-app", "kind": "v6"}
    policy["expected"]["ips"].append(extra)
    resources["envelope"]["ips"].insert(0, extra)
    resources["inventory_coverage"].reverse()
    assert evaluate(policy, resources, billing)["resources"] == "CONSISTENT"


def test_missing_evidence_has_distinct_reasons():
    policy, _, _ = documents()
    assert evaluate(policy, None, None)["reason_codes"] == [
        "RESOURCE_EVIDENCE_MISSING", "BILLING_EVIDENCE_MISSING",
    ]
    assert evaluate(None, None, None)["reason_codes"] == ["POLICY_MISSING"]


@pytest.mark.parametrize("raw", [
    '{"schema_version":1,"schema_version":1}',
    '{"nested":{"amount":1,"amount":2}}',
    '{"amount":NaN}', '{"amount":Infinity}', '{"amount":-Infinity}',
    '{"amount":1.0}', '{"amount":1e6}', CANARY,
    '{"nested":' + '[' * 2000 + ']' * 2000 + '}',
], ids=["duplicate", "nested-duplicate", "nan", "infinity", "negative-infinity",
        "float", "exponent", "invalid", "excessive-nesting"])
def test_duplicate_nonfinite_float_invalid_and_deep_json_fail_closed(tmp_path, raw):
    path = tmp_path / "private.json"
    path.write_text(raw)
    path.chmod(0o600)
    assert spend.load_document(path) is spend.INVALID_DOCUMENT


def test_private_file_read_is_bounded_and_read_only(tmp_path):
    path = write_private(tmp_path / "private.json", documents()[0])
    before = path.read_bytes()
    before_entries = set(tmp_path.iterdir())
    assert spend.load_document(path) == documents()[0]
    assert path.read_bytes() == before
    assert set(tmp_path.iterdir()) == before_entries
    path.write_bytes(b" " * (spend.MAX_INPUT_BYTES + 1))
    assert spend.load_document(path) is spend.INVALID_DOCUMENT


def test_symlink_hardlink_permissions_fifo_and_absent_files_are_rejected(tmp_path):
    path = write_private(tmp_path / "private.json", documents()[0])
    link = tmp_path / "symlink.json"
    link.symlink_to(path)
    assert spend.load_document(link) is spend.INVALID_DOCUMENT
    hardlink = tmp_path / "hardlink.json"
    os.link(path, hardlink)
    assert spend.load_document(hardlink) is spend.INVALID_DOCUMENT
    hardlink.unlink()
    path.chmod(0o644)
    assert spend.load_document(path) is spend.INVALID_DOCUMENT
    fifo = tmp_path / "pipe"
    os.mkfifo(fifo, 0o600)
    assert spend.load_document(fifo) is spend.INVALID_DOCUMENT
    assert spend.load_document(tmp_path / "missing.json") is None
    assert spend.load_document(None) is None


def test_cli_does_not_echo_sensitive_paths_arguments_or_inputs(tmp_path, capsys):
    policy = write_private(tmp_path / CANARY, documents()[0])
    assert spend.main(["--policy", str(policy)]) == 2
    output = capsys.readouterr()
    assert CANARY not in output.out + output.err
    assert "POLICY_INVALID" not in output.out
    assert "RESOURCE_EVIDENCE_MISSING" in output.out
    assert spend.main(["--policy", str(policy), "--unexpected", CANARY]) == 2
    output = capsys.readouterr()
    assert CANARY not in output.out + output.err
    assert json.loads(output.out)["reason_codes"] == ["ARGUMENTS_INVALID"]
