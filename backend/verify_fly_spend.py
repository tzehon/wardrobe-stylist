#!/usr/bin/env python3
"""Assess explicitly supplied private Fly evidence locally, without provider access.

This is not a scheduler, live billing reader, forecast, invoice cap, or AI-enablement gate.
Manually supplied source names/revision hashes establish consistency, not authenticity.
No input is persisted and output contains only fixed public labels. Run with explicit
owner-only JSON files: --policy PATH [--resources PATH] [--billing PATH]. Nothing creates
a policy or normalizes an old billing record automatically.

The strict input models below are the version-1 contract. Policy amounts are integer
millionths of USD; limits, identities, freshness tolerances and the expected resource
envelope must come from the separately reviewed private policy. ``policy_revision`` is
the recomputed SHA-256 of validated policy content excluding that field, repeated by each
evidence document. Resource collections are normalized by ``canonical_envelope``; JSON
object keys are sorted, separators are compact, and ASCII-escaped JSON is UTF-8 encoded.
This detects stale content bindings, not external approval or authenticity. ``source_revision``
identifies each retained source record; this helper does not authenticate that record.
All times must be explicit UTC ISO timestamps ending in Z. Null billing coverage means
unknown, never current. Net payable is retained separately and never used as consumption.
Only observed pre-tax consumption is compared; future scenarios are not assessed here.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import stat
from collections.abc import Sequence
from datetime import UTC, datetime
from pathlib import Path
from typing import Annotated, Literal, Never

from pydantic import BaseModel, ConfigDict, Field, ValidationError, field_validator

MAX_INPUT_BYTES = 256 * 1024
MAX_INTEGER = 10**15  # Parser bound, not an operating allowance.
MAX_ROWS = 1000
Unsigned = Annotated[int, Field(strict=True, ge=0, le=MAX_INTEGER)]
Positive = Annotated[int, Field(strict=True, ge=1, le=MAX_INTEGER)]
Identifier = Annotated[str, Field(min_length=1, max_length=256, pattern=r"^[\w.:/@+-]+$")]
Revision = Annotated[str, Field(pattern=r"^[0-9a-f]{64}$")]
CoverageKind = Literal["apps", "machines", "volumes", "ips", "services", "linked_organizations"]
REQUIRED_COVERAGE = {"apps", "machines", "volumes", "ips", "services", "linked_organizations"}
INVALID_DOCUMENT = object()


class PrivateModel(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True, hide_input_in_errors=True)


class Machine(PrivateModel):
    id: Identifier
    app: Identifier
    region: Identifier
    cpu_kind: Identifier
    cpu_count: Positive
    memory_mb: Positive
    image_revision: Identifier
    volume_ids: list[Identifier] = Field(max_length=MAX_ROWS)
    state: Literal["started", "stopped", "suspended"]


class Volume(PrivateModel):
    id: Identifier
    app: Identifier
    region: Identifier
    size_gb: Positive
    encrypted: bool
    snapshot_retention_days: Positive
    automatic_snapshots: bool


class IP(PrivateModel):
    id: Identifier
    app: Identifier
    kind: Identifier


class Service(PrivateModel):
    id: Identifier
    kind: Identifier


class Envelope(PrivateModel):
    organization: Identifier
    apps: list[Identifier] = Field(max_length=MAX_ROWS)
    machines: list[Machine] = Field(max_length=MAX_ROWS)
    volumes: list[Volume] = Field(max_length=MAX_ROWS)
    ips: list[IP] = Field(max_length=MAX_ROWS)
    services: list[Service] = Field(max_length=MAX_ROWS)
    linked_organizations: list[Identifier] = Field(max_length=MAX_ROWS)


class Policy(PrivateModel):
    schema_version: Annotated[int, Field(strict=True, ge=1, le=1)]
    policy_revision: Revision
    currency: Literal["USD"]
    unit: Literal["millionth_usd"]
    warning_units: Positive
    hold_units: Positive
    operating_target_units: Positive
    resource_max_age_seconds: Positive
    billing_observation_max_age_seconds: Positive
    billing_coverage_max_age_seconds: Positive
    expected: Envelope


class TimedEvidence(PrivateModel):
    observed_at: str
    source_revision: Revision

    @field_validator("observed_at")
    @classmethod
    def valid_time(cls, value: str) -> str:
        utc_time(value)
        return value


class ResourceEvidence(TimedEvidence):
    schema_version: Annotated[int, Field(strict=True, ge=1, le=1)]
    policy_revision: Revision
    source: Literal["flyctl_and_console_manual_v1"]
    inventory_coverage: list[CoverageKind] = Field(max_length=6)
    envelope: Envelope


class BillingView(TimedEvidence):
    pretax_consumption_units: Unsigned | None
    net_payable_units: Unsigned | None
    coverage_starts_at: str | None
    coverage_ends_at: str | None


    @field_validator("coverage_starts_at", "coverage_ends_at")
    @classmethod
    def valid_coverage_time(cls, value: str | None) -> str | None:
        if value is not None:
            utc_time(value)
        return value


class InvoiceView(BillingView):
    source: Literal["fly_invoice_preview_manual_v1"]


class ExplorerView(BillingView):
    source: Literal["fly_cost_explorer_manual_v1"]


class BillingEvidence(PrivateModel):
    schema_version: Annotated[int, Field(strict=True, ge=1, le=1)]
    policy_revision: Revision
    currency: Literal["USD"]
    unit: Literal["millionth_usd"]
    period_starts_at: str
    period_ends_at: str
    invoice: InvoiceView
    cost_explorer: ExplorerView


def utc_time(value: str) -> datetime:
    """Require explicit UTC, without silently fixing offsets or naive timestamps."""
    if not value.endswith("Z") or "T" not in value:
        raise ValueError("invalid time")
    parsed = datetime.fromisoformat(value)
    if parsed.tzinfo != UTC:
        raise ValueError("invalid time")
    return parsed


def canonical_envelope(envelope: Envelope) -> str:
    """Reject duplicate/inconsistent rows, then compare independent of input ordering."""
    value = envelope.model_dump()
    for name in ("apps", "linked_organizations"):
        rows = value[name]
        if len(set(rows)) != len(rows):
            raise ValueError("duplicate identity")
        rows.sort()
    for name in ("machines", "volumes", "ips", "services"):
        rows = value[name]
        keys = [(row.get("kind"), row["id"]) if name == "services" else row["id"]
                for row in rows]
        if len(set(keys)) != len(rows):
            raise ValueError("duplicate identity")
        if name != "services" and any(row["app"] not in value["apps"] for row in rows):
            raise ValueError("unlisted app")
        rows.sort(key=lambda row: (row.get("kind", ""), row["id"]))
    volumes = {volume.id: volume for volume in envelope.volumes}
    mounted: set[str] = set()
    for machine in value["machines"]:
        ids = machine["volume_ids"]
        if len(set(ids)) != len(ids) or mounted.intersection(ids):
            raise ValueError("duplicate volume mount")
        for volume_id in ids:
            if volume_id not in volumes or volumes[volume_id].app != machine["app"]:
                raise ValueError("unknown volume mount")
        mounted.update(ids)
        ids.sort()
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def policy_content_sha256(policy: Policy) -> str:
    """Bind every validated policy field except its digest, without asserting approval."""
    content = policy.model_dump(exclude={"policy_revision"})
    content["expected"] = json.loads(canonical_envelope(policy.expected))
    canonical = json.dumps(
        content, sort_keys=True, separators=(",", ":"), ensure_ascii=True, allow_nan=False,
    ).encode("utf-8")
    return hashlib.sha256(canonical).hexdigest()


def assess_resources(document: object, policy: Policy, now: datetime) -> list[str]:
    if document is None:
        return ["RESOURCE_EVIDENCE_MISSING"]
    try:
        evidence = ResourceEvidence.model_validate(document)
        actual = canonical_envelope(evidence.envelope)
        if evidence.policy_revision != policy.policy_revision:
            return ["RESOURCE_POLICY_REVISION_MISMATCH"]
        observed = utc_time(evidence.observed_at)
        if observed > now or len(set(evidence.inventory_coverage)) != len(
            evidence.inventory_coverage
        ):
            return ["RESOURCE_EVIDENCE_INVALID"]
    except (ValidationError, ValueError, TypeError, RecursionError):
        return ["RESOURCE_EVIDENCE_INVALID"]
    reasons = []
    if actual != canonical_envelope(policy.expected):
        reasons.append("RESOURCE_ENVELOPE_MISMATCH")
    if set(evidence.inventory_coverage) != REQUIRED_COVERAGE:
        reasons.append("RESOURCE_COVERAGE_INCOMPLETE")
    if (now - observed).total_seconds() > policy.resource_max_age_seconds:
        reasons.append("RESOURCE_EVIDENCE_STALE")
    return reasons


def assess_billing(
    document: object, policy: Policy, now: datetime,
) -> tuple[list[str], str]:
    if document is None:
        return ["BILLING_EVIDENCE_MISSING"], "UNKNOWN"
    try:
        evidence = BillingEvidence.model_validate(document)
        if evidence.policy_revision != policy.policy_revision:
            return ["BILLING_POLICY_REVISION_MISMATCH"], "UNKNOWN"
        start = utc_time(evidence.period_starts_at)
        end = utc_time(evidence.period_ends_at)
        current = datetime(now.year, now.month, 1, tzinfo=UTC)
        following = datetime(now.year + (now.month == 12), now.month % 12 + 1, 1, tzinfo=UTC)
        if start != current or end != following:
            return ["BILLING_PERIOD_NOT_CURRENT"], "UNKNOWN"
        views = (evidence.invoice, evidence.cost_explorer)
        coverages: list[tuple[datetime | None, datetime | None]] = []
        for view in views:
            observed = utc_time(view.observed_at)
            covered_start = utc_time(view.coverage_starts_at) if view.coverage_starts_at else None
            covered_end = utc_time(view.coverage_ends_at) if view.coverage_ends_at else None
            if not start <= observed <= now:
                raise ValueError("invalid observation")
            if covered_start is not None and not start <= covered_start <= observed:
                raise ValueError("invalid coverage")
            if covered_end is not None and not start <= covered_end <= observed:
                raise ValueError("invalid coverage")
            if (
                covered_start is not None and covered_end is not None
                and covered_start > covered_end
            ):
                raise ValueError("invalid coverage")
            coverages.append((covered_start, covered_end))
    except (ValidationError, ValueError, TypeError, RecursionError):
        return ["BILLING_EVIDENCE_INVALID"], "UNKNOWN"

    known = [view.pretax_consumption_units for view in views
             if view.pretax_consumption_units is not None]
    largest = max(known, default=-1)
    # Preserve validated adverse observations even while reconciliation/freshness is open.
    threshold = (
        "HOLD_REQUIRED" if largest >= policy.hold_units else
        "WARNING" if largest >= policy.warning_units else "UNKNOWN"
    )
    reasons = []
    if len(known) != 2:
        reasons.append("BILLING_PRETAX_CONSUMPTION_MISSING")
    elif known[0] != known[1]:
        reasons.append("BILLING_TOTALS_UNRECONCILED")
    if any(start_value is None or end_value is None for start_value, end_value in coverages):
        reasons.append("BILLING_COVERAGE_UNKNOWN")
    elif any(start_value != start for start_value, _ in coverages):
        reasons.append("BILLING_COVERAGE_INCOMPLETE")
    if coverages[0] != coverages[1]:
        reasons.append("BILLING_COVERAGE_UNRECONCILED")
    if any((now - utc_time(view.observed_at)).total_seconds()
           > policy.billing_observation_max_age_seconds for view in views):
        reasons.append("BILLING_OBSERVATION_STALE")
    if any(end_value is not None and (now - end_value).total_seconds()
           > policy.billing_coverage_max_age_seconds for _, end_value in coverages):
        reasons.append("BILLING_COVERAGE_STALE")
    if not reasons and threshold == "UNKNOWN":
        threshold = "NO_OBSERVED_THRESHOLD_CROSSING"
    return reasons, threshold


def assess(
    policy_document: object, resource_document: object, billing_document: object, *, now: datetime,
) -> dict[str, object]:
    """Assess supplied records; even consistent records confer no operational authority."""
    result: dict[str, object] = {
        "scope": "LOCAL_EVIDENCE_ONLY",
        "assessment": "OPEN",
        "resources": "OPEN",
        "billing": "OPEN",
        "observed_consumption": "UNKNOWN",
        "forecast": "NOT_ASSESSED",
        "live_provenance": "NOT_VERIFIED",
        "activation_authority": "NONE",
        "hold_execution": "NOT_PERFORMED",
        "reason_codes": [],
    }
    try:
        if now.tzinfo != UTC:
            raise ValueError("invalid clock")
        policy = Policy.model_validate(policy_document)
        if not policy.warning_units < policy.hold_units < policy.operating_target_units:
            raise ValueError("invalid threshold order")
        content_revision = policy_content_sha256(policy)
    except (ValidationError, ValueError, TypeError, RecursionError):
        result["reason_codes"] = [
            "POLICY_MISSING" if policy_document is None else "POLICY_INVALID"
        ]
        return result
    if policy.policy_revision != content_revision:
        result["reason_codes"] = ["POLICY_CONTENT_REVISION_MISMATCH"]
        return result
    resource_reasons = assess_resources(resource_document, policy, now)
    billing_reasons, threshold = assess_billing(billing_document, policy, now)
    result["resources"] = "OPEN" if resource_reasons else "CONSISTENT"
    result["billing"] = "OPEN" if billing_reasons else "CONSISTENT"
    result["observed_consumption"] = threshold
    result["reason_codes"] = resource_reasons + billing_reasons
    if (
        not resource_reasons and not billing_reasons
        and threshold == "NO_OBSERVED_THRESHOLD_CROSSING"
    ):
        result["assessment"] = "CONSISTENT_LOCAL_EVIDENCE"
    return result


def _pairs(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON key")
        result[key] = value
    return result


def _reject_number(value: str) -> object:
    raise ValueError("non-integer JSON number")


def _bounded_object(document: object) -> object:
    if not isinstance(document, dict):
        return INVALID_DOCUMENT
    pending = [(document, 0)]
    while pending:
        value, depth = pending.pop()
        if depth > 16:
            return INVALID_DOCUMENT
        if isinstance(value, dict):
            pending.extend((child, depth + 1) for child in value.values())
        elif isinstance(value, list):
            pending.extend((child, depth + 1) for child in value)
    return document


def load_document(path: Path | None) -> object:
    """Read one bounded owner-only regular file, without echoing data or failure details."""
    if path is None:
        return None
    try:
        descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        with os.fdopen(descriptor, "rb") as stream:
            metadata = os.fstat(stream.fileno())
            if (
                not stat.S_ISREG(metadata.st_mode)
                or stat.S_IMODE(metadata.st_mode) != 0o600
                or metadata.st_uid != os.getuid()
                or metadata.st_nlink != 1
                or metadata.st_size > MAX_INPUT_BYTES
            ):
                return INVALID_DOCUMENT
            data = stream.read(MAX_INPUT_BYTES + 1)
        if len(data) > MAX_INPUT_BYTES:
            return INVALID_DOCUMENT
        return _bounded_object(json.loads(
            data, object_pairs_hook=_pairs, parse_float=_reject_number,
            parse_constant=_reject_number,
        ))
    except FileNotFoundError:
        return None
    except (OSError, ValueError, TypeError, RecursionError):
        return INVALID_DOCUMENT


class SafeParser(argparse.ArgumentParser):
    def error(self, message: str) -> Never:
        raise ValueError("invalid arguments")


def main(argv: Sequence[str] | None = None) -> int:
    parser = SafeParser(description=__doc__)
    parser.add_argument("--policy", type=Path, required=True)
    parser.add_argument("--resources", type=Path)
    parser.add_argument("--billing", type=Path)
    try:
        arguments = parser.parse_args(argv)
    except ValueError:
        print(json.dumps({"scope": "LOCAL_EVIDENCE_ONLY", "assessment": "OPEN",
                          "reason_codes": ["ARGUMENTS_INVALID"]}))
        return 2
    result = assess(
        load_document(arguments.policy), load_document(arguments.resources),
        load_document(arguments.billing), now=datetime.now(UTC),
    )
    print(json.dumps(result, sort_keys=True))
    return 0 if result["assessment"] == "CONSISTENT_LOCAL_EVIDENCE" else 2


if __name__ == "__main__":
    raise SystemExit(main())
