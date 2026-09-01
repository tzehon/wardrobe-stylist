#!/usr/bin/env python3
"""Run the redacted, owner-triggered production pre-upload preflight.

The command intentionally performs no provider mutation and never uploads a build. Raw Fly,
Docker, HTTP, SQLite, and signed-in-review inputs are parsed in memory and discarded. Output is
restricted to fixed check names, fixed result codes, the review UTC, and the newest snapshot's
policy-approved UTC/status/retention fields.

Three surfaces remain human-reviewed because the repository has no supported read-only API for
them: Fly's official aggregate HTTP status-class metric, signed-in Anthropic usage/limit/model
state, and App Store Connect Build Uploads. A short-lived TOML attestation may combine those fresh
observations with the automated checks, but explicit owner approval to upload is always separate.
"""

from __future__ import annotations

import argparse
import base64
import ipaddress
import json
import os
import plistlib
import re
import selectors
import signal
import subprocess
import sys
import tempfile
import time
import tomllib
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from enum import StrEnum
from html.parser import HTMLParser
from pathlib import Path
from typing import Any, Protocol
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin, urlsplit, urlunsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

MAX_CAPTURE_BYTES = 4 * 1024 * 1024
MAX_HTTP_BYTES = 1024 * 1024
COMMAND_TIMEOUT_SECONDS = 30
LOG_TIMEOUT_SECONDS = 20
SNAPSHOT_MAX_AGE = timedelta(hours=36)
EVENT_WINDOW = timedelta(minutes=10)
RUNTIME_INPUT_PATHS = (
    "backend/.dockerignore",
    "backend/Dockerfile",
    "backend/app",
    "backend/container_entrypoint.py",
    "backend/fly.toml",
    "backend/pyproject.toml",
    "backend/uv.lock",
    "backend/uvicorn-logging.json",
    "shared/schemas",
)


class ReviewConfigurationError(ValueError):
    """Raised when local review configuration cannot be trusted."""


class Status(StrEnum):
    PASS = "PASS"
    WARNING = "WARNING"
    OPEN = "OPEN"


_DETAILS: dict[str, frozenset[str]] = {
    "source": frozenset({"clean-synchronized", "local-source-open"}),
    "archive": frozenset({"strict-artifact-match", "archive-open"}),
    "fly_runtime": frozenset(
        {"exact-healthy-runtime", "runtime-evidence-open"}
    ),
    "fly_configuration": frozenset(
        {"app-attest-only", "configuration-evidence-open"}
    ),
    "auth_store": frozenset(
        {"schema-integrity-and-runtime-guards", "auth-store-evidence-open"}
    ),
    "auth_aggregate": frozenset(
        {"single-user-band", "auth-aggregate-open"}
    ),
    "volume": frozenset(
        {
            "below-70-percent",
            "70-to-84-percent",
            "85-percent-or-more",
            "volume-evidence-open",
        }
    ),
    "snapshot": frozenset(
        {"automatic-14-day-fresh", "snapshot-evidence-open"}
    ),
    "bounded_events": frozenset(
        {"below-policy-threshold", "failure-cluster-open", "event-evidence-open"}
    ),
    "public_backend": frozenset(
        {"health-and-routes", "public-backend-open"}
    ),
    "public_pages": frozenset(
        {"support-privacy-terms", "public-pages-open"}
    ),
    "anthropic_status": frozenset(
        {"public-status-operational", "public-status-open"}
    ),
    "recovery_scan": frozenset(
        {"exact-linux-amd64-zero-high-critical", "recovery-scan-open"}
    ),
    "official_fly_metrics": frozenset(
        {"fresh-signed-in-pass", "manual-review-required", "manual-review-open"}
    ),
    "anthropic_console": frozenset(
        {
            "fresh-signed-in-pass",
            "fresh-signed-in-warning",
            "manual-review-required",
            "manual-review-open",
        }
    ),
    "app_store_connect": frozenset(
        {"fresh-signed-in-pass", "manual-review-required", "manual-review-open"}
    ),
}

_PASS_DETAILS = {
    "source": "clean-synchronized",
    "archive": "strict-artifact-match",
    "fly_runtime": "exact-healthy-runtime",
    "fly_configuration": "app-attest-only",
    "auth_store": "schema-integrity-and-runtime-guards",
    "auth_aggregate": "single-user-band",
    "volume": "below-70-percent",
    "snapshot": "automatic-14-day-fresh",
    "bounded_events": "below-policy-threshold",
    "public_backend": "health-and-routes",
    "public_pages": "support-privacy-terms",
    "anthropic_status": "public-status-operational",
    "recovery_scan": "exact-linux-amd64-zero-high-critical",
    "official_fly_metrics": "fresh-signed-in-pass",
    "anthropic_console": "fresh-signed-in-pass",
    "app_store_connect": "fresh-signed-in-pass",
}
_WARNING_RESULTS = frozenset(
    {
        ("volume", "70-to-84-percent"),
        ("anthropic_console", "fresh-signed-in-warning"),
    }
)

CHECK_ORDER = tuple(_DETAILS)


@dataclass(frozen=True)
class CheckResult:
    name: str
    status: Status
    detail: str

    def __post_init__(self) -> None:
        pair = (self.name, self.detail)
        if self.name not in _DETAILS or self.detail not in _DETAILS[self.name]:
            raise ReviewConfigurationError("review result used an unapproved field")
        expected_status = (
            Status.PASS
            if _PASS_DETAILS[self.name] == self.detail
            else Status.WARNING
            if pair in _WARNING_RESULTS
            else Status.OPEN
        )
        if self.status is not expected_status:
            raise ReviewConfigurationError("review result used an invalid status")


@dataclass(frozen=True)
class SnapshotMetadata:
    created_at: datetime
    status: str
    retention_days: int

    def __post_init__(self) -> None:
        if self.created_at.tzinfo is None:
            raise ReviewConfigurationError("snapshot timestamp must be UTC-aware")
        if self.status != "created" or self.retention_days != 14:
            raise ReviewConfigurationError("snapshot metadata is not safe to retain")


@dataclass(frozen=True)
class ReviewReport:
    checked_at: datetime
    results: tuple[CheckResult, ...]
    snapshot: SnapshotMetadata | None = None

    @property
    def passed(self) -> bool:
        return (
            tuple(result.name for result in self.results) == CHECK_ORDER
            and all(result.status is Status.PASS for result in self.results)
        )

    def render(self) -> str:
        lines = [f"checked_at_utc={_format_utc(self.checked_at)}"]
        by_name = {result.name: result for result in self.results}
        for name in CHECK_ORDER:
            result = by_name[name]
            lines.append(f"{name}={result.status.value} {result.detail}")
        if self.snapshot is not None:
            lines.extend(
                (
                    f"snapshot_newest_utc={_format_utc(self.snapshot.created_at)}",
                    f"snapshot_newest_status={self.snapshot.status}",
                    f"snapshot_retention_days={self.snapshot.retention_days}",
                )
            )
        lines.append(
            "preupload_evidence="
            + (
                "PASS owner-upload-approval-still-required"
                if self.passed
                else "OPEN owner-upload-approval-not-requested"
            )
        )
        return "\n".join(lines)


@dataclass(frozen=True)
class ReviewConfig:
    deployed_revision: str
    source_repository: str
    fly_app: str
    fly_release_version: int
    region: str
    archive_basename: str
    marketing_version: str
    build_number: str
    app_cdhash: str
    dsym_uuid: str
    backend_url: str
    auth_schema_version: int
    app_attest_app_id_prefix: str
    app_attest_bundle_id: str
    validation_categories: tuple[str, ...]
    bundle_versions: tuple[str, ...]
    required_secret_names: frozenset[str]
    expected_routes: frozenset[str]
    terms_url: str
    anthropic_status_url: str
    manual_evidence_max_age: timedelta

    @classmethod
    def load(cls, path: Path) -> ReviewConfig:
        try:
            raw = tomllib.loads(path.read_text(encoding="utf-8"))
            if raw.get("schema_version") != 1:
                raise ValueError
            revision = _required_text(raw, "expected_deployed_revision")
            if re.fullmatch(r"[0-9a-f]{40}", revision) is None:
                raise ValueError
            app_cdhash = _required_text(raw, "expected_app_cdhash").lower()
            if re.fullmatch(r"[0-9a-f]{40}", app_cdhash) is None:
                raise ValueError
            dsym_uuid = _required_text(raw, "expected_dsym_uuid").lower()
            if re.fullmatch(
                r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
                dsym_uuid,
            ) is None:
                raise ValueError
            source_repository = _required_public_https_url(
                raw, "expected_source_repository"
            )
            backend_url = _required_public_https_url(raw, "expected_backend_url")
            terms_url = _required_public_https_url(raw, "terms_url")
            status_url = _required_public_https_url(raw, "anthropic_status_url")
            fly_release_version = _required_positive_int(
                raw, "expected_fly_release_version"
            )
            auth_schema_version = _required_positive_int(
                raw, "expected_auth_schema_version"
            )
            max_age_minutes = _required_positive_int(
                raw, "manual_evidence_max_age_minutes"
            )
            if max_age_minutes > 120:
                raise ValueError
            return cls(
                deployed_revision=revision,
                source_repository=source_repository,
                fly_app=_required_text(raw, "expected_fly_app"),
                fly_release_version=fly_release_version,
                region=_required_text(raw, "expected_region"),
                archive_basename=_required_text(raw, "expected_archive_basename"),
                marketing_version=_required_text(raw, "expected_marketing_version"),
                build_number=_required_text(raw, "expected_build_number"),
                app_cdhash=app_cdhash,
                dsym_uuid=dsym_uuid,
                backend_url=backend_url.rstrip("/"),
                auth_schema_version=auth_schema_version,
                app_attest_app_id_prefix=_required_text(
                    raw, "expected_app_attest_app_id_prefix"
                ),
                app_attest_bundle_id=_required_text(
                    raw, "expected_app_attest_bundle_id"
                ),
                validation_categories=_required_text_tuple(
                    raw, "expected_validation_categories"
                ),
                bundle_versions=_required_text_tuple(raw, "expected_bundle_versions"),
                required_secret_names=frozenset(
                    _required_text_tuple(raw, "required_secret_names")
                ),
                expected_routes=frozenset(
                    _required_text_tuple(raw, "expected_routes")
                ),
                terms_url=terms_url,
                anthropic_status_url=status_url,
                manual_evidence_max_age=timedelta(minutes=max_age_minutes),
            )
        except (OSError, UnicodeError, tomllib.TOMLDecodeError, ValueError, TypeError):
            raise ReviewConfigurationError(
                "production operations configuration is invalid"
            ) from None


@dataclass(frozen=True)
class CommandOutput:
    returncode: int
    stdout: str = ""
    stderr: str = ""
    timed_out: bool = False


class CommandRunning(Protocol):
    def run(
        self,
        argv: Sequence[str],
        *,
        timeout: int = COMMAND_TIMEOUT_SECONDS,
        env: dict[str, str] | None = None,
    ) -> CommandOutput: ...


class SubprocessRunner:
    """Capture commands without a shell and never surface provider output."""

    @staticmethod
    def _kill_process_group(process: subprocess.Popen[bytes]) -> None:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except (OSError, ProcessLookupError):
            try:
                process.kill()
            except OSError:
                pass
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            pass

    def run(
        self,
        argv: Sequence[str],
        *,
        timeout: int = COMMAND_TIMEOUT_SECONDS,
        env: dict[str, str] | None = None,
    ) -> CommandOutput:
        try:
            process = subprocess.Popen(  # noqa: S603 - fixed argv only
                list(argv),
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
                start_new_session=True,
            )
        except OSError:
            return CommandOutput(returncode=127)
        if process.stdout is None or process.stderr is None:
            self._kill_process_group(process)
            return CommandOutput(returncode=125)
        selector = selectors.DefaultSelector()
        selector.register(process.stdout, selectors.EVENT_READ, "stdout")
        selector.register(process.stderr, selectors.EVENT_READ, "stderr")
        captured = {"stdout": bytearray(), "stderr": bytearray()}
        deadline = time.monotonic() + max(0, timeout)
        timed_out = False
        overflow = False
        try:
            while selector.get_map():
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    timed_out = True
                    break
                for key, _ in selector.select(timeout=min(remaining, 0.25)):
                    try:
                        chunk = os.read(key.fd, 64 * 1024)
                    except OSError:
                        chunk = b""
                    if not chunk:
                        selector.unregister(key.fileobj)
                        key.fileobj.close()
                        continue
                    buffer = captured[str(key.data)]
                    capacity = MAX_CAPTURE_BYTES - len(buffer)
                    if len(chunk) > capacity:
                        buffer.extend(chunk[:capacity])
                        overflow = True
                        break
                    buffer.extend(chunk)
                if overflow:
                    break
            if timed_out or overflow:
                self._kill_process_group(process)
            else:
                try:
                    process.wait(timeout=max(0.01, deadline - time.monotonic()))
                except subprocess.TimeoutExpired:
                    timed_out = True
                    self._kill_process_group(process)
        finally:
            selector.close()
            for stream in (process.stdout, process.stderr):
                if not stream.closed:
                    stream.close()
        if overflow:
            return CommandOutput(returncode=125)
        return CommandOutput(
            returncode=process.returncode if process.returncode is not None else 125,
            stdout=bytes(captured["stdout"]).decode("utf-8", errors="replace"),
            stderr=bytes(captured["stderr"]).decode("utf-8", errors="replace"),
            timed_out=timed_out,
        )


@dataclass(frozen=True)
class HTTPResponse:
    status: int
    final_url: str
    body: bytes


class HTTPGetting(Protocol):
    def get(self, url: str, *, timeout: int = 15) -> HTTPResponse | None: ...


class _SameHostHTTPSRedirectHandler(HTTPRedirectHandler):
    def redirect_request(
        self,
        req: Request,
        fp: Any,
        code: int,
        msg: str,
        headers: Any,
        newurl: str,
    ) -> Request | None:
        before = urlsplit(req.full_url)
        after = urlsplit(newurl)
        if (
            before.scheme != "https"
            or after.scheme != "https"
            or before.hostname != after.hostname
        ):
            return None
        return super().redirect_request(req, fp, code, msg, headers, newurl)


class UrllibHTTPGetter:
    def __init__(self) -> None:
        self._opener = build_opener(_SameHostHTTPSRedirectHandler())

    def get(self, url: str, *, timeout: int = 15) -> HTTPResponse | None:
        if not _is_public_https_url(url):
            return None
        request = Request(
            url,
            method="GET",
            headers={"User-Agent": "Wardrobe-Production-Preflight/1"},
        )
        try:
            with self._opener.open(request, timeout=timeout) as response:
                body = response.read(MAX_HTTP_BYTES + 1)
                if len(body) > MAX_HTTP_BYTES:
                    return None
                return HTTPResponse(
                    status=int(response.status),
                    final_url=response.geturl(),
                    body=body,
                )
        except HTTPError as error:
            try:
                body = error.read(MAX_HTTP_BYTES + 1)
            except OSError:
                return None
            if len(body) > MAX_HTTP_BYTES:
                return None
            return HTTPResponse(
                status=int(error.code),
                final_url=error.geturl(),
                body=body,
            )
        except (OSError, URLError, ValueError):
            return None


@dataclass(frozen=True)
class ArchiveContext:
    backend_url: str
    privacy_url: str
    support_url: str


@dataclass(frozen=True)
class RuntimeContext:
    app: str
    machine_id: str
    image_ref: str
    machine_config: dict[str, Any]


@dataclass(frozen=True)
class StorageContext:
    volume_id: str
    snapshot: SnapshotMetadata


def _pass(name: str, detail: str) -> CheckResult:
    return CheckResult(name=name, status=Status.PASS, detail=detail)


def _warning(name: str, detail: str) -> CheckResult:
    return CheckResult(name=name, status=Status.WARNING, detail=detail)


def _open(name: str, detail: str) -> CheckResult:
    return CheckResult(name=name, status=Status.OPEN, detail=detail)


def _required_text(values: dict[str, Any], key: str) -> str:
    value = values.get(key)
    if not isinstance(value, str) or not value.strip():
        raise ValueError
    return value.strip()


def _required_positive_int(values: dict[str, Any], key: str) -> int:
    value = values.get(key)
    if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
        raise ValueError
    return value


def _required_text_tuple(values: dict[str, Any], key: str) -> tuple[str, ...]:
    raw = values.get(key)
    if (
        not isinstance(raw, list)
        or not raw
        or any(not isinstance(value, str) or not value.strip() for value in raw)
    ):
        raise ValueError
    result = tuple(value.strip() for value in raw)
    if len(set(result)) != len(result):
        raise ValueError
    return result


def _required_public_https_url(values: dict[str, Any], key: str) -> str:
    value = _required_text(values, key)
    if not _is_public_https_url(value):
        raise ValueError
    return value


def _is_public_https_url(value: str) -> bool:
    try:
        parts = urlsplit(value)
        _ = parts.port
    except ValueError:
        return False
    hostname = (parts.hostname or "").rstrip(".").lower()
    try:
        address = ipaddress.ip_address(hostname)
    except ValueError:
        address = None
    return (
        parts.scheme == "https"
        and bool(hostname)
        and "." in hostname
        and parts.username is None
        and parts.password is None
        and hostname != "localhost"
        and not hostname.endswith((".local", ".test", ".invalid", ".home.arpa"))
        and (address is None or address.is_global)
    )


def _format_utc(value: datetime) -> str:
    return value.astimezone(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _clock_utc(clock: Callable[[], datetime]) -> datetime:
    value = clock()
    if value.tzinfo is None:
        raise ReviewConfigurationError("review clock must be UTC-aware")
    return value.astimezone(UTC)


def _parse_utc(value: object) -> datetime | None:
    if not isinstance(value, str) or len(value) > 64:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return None
    return parsed.astimezone(UTC)


def _json_output(
    runner: CommandRunning,
    argv: Sequence[str],
    *,
    timeout: int = COMMAND_TIMEOUT_SECONDS,
    env: dict[str, str] | None = None,
) -> Any | None:
    result = runner.run(argv, timeout=timeout, env=env)
    if result.returncode != 0 or result.timed_out:
        return None
    try:
        return json.loads(result.stdout)
    except (json.JSONDecodeError, UnicodeError):
        return None


def _dict_rows(value: object) -> list[dict[str, Any]] | None:
    if not isinstance(value, list) or any(not isinstance(row, dict) for row in value):
        return None
    return list(value)


def _json_object_stream(value: str) -> list[dict[str, Any]] | None:
    decoder = json.JSONDecoder()
    rows: list[dict[str, Any]] = []
    index = 0
    while index < len(value):
        while index < len(value) and value[index].isspace():
            index += 1
        if index == len(value):
            break
        try:
            row, index = decoder.raw_decode(value, index)
        except json.JSONDecodeError:
            return None
        if not isinstance(row, dict):
            return None
        rows.append(row)
    return rows


def _as_rows(value: object) -> list[dict[str, Any]]:
    if isinstance(value, dict):
        return [value]
    if isinstance(value, list) and all(isinstance(row, dict) for row in value):
        return list(value)
    return []


def _digest_from_ref(reference: object) -> str | None:
    if not isinstance(reference, str) or len(reference) > 512 or "@" not in reference:
        return None
    digest = reference.rsplit("@", 1)[1]
    return digest if re.fullmatch(r"sha256:[0-9a-f]{64}", digest) else None


def _release_version(value: object) -> int | None:
    if isinstance(value, int) and not isinstance(value, bool) and value > 0:
        return value
    if isinstance(value, str) and re.fullmatch(r"[1-9][0-9]*", value):
        return int(value)
    return None


def _canonical_repository(value: object) -> str | None:
    if not isinstance(value, str) or len(value) > 512:
        return None
    cleaned = value.strip().removesuffix(".git").rstrip("/")
    ssh_match = re.fullmatch(r"git@github\.com:([^/]+)/(.+)", cleaned)
    if ssh_match:
        cleaned = f"https://github.com/{ssh_match.group(1)}/{ssh_match.group(2)}"
    return cleaned.lower()


def _remote_main_hash(output: str) -> str | None:
    match = re.fullmatch(
        r"([0-9a-f]{40})\trefs/heads/main\n?", output
    )
    return match.group(1) if match is not None else None


def check_source(
    runner: CommandRunning,
    *,
    repo_root: Path,
    config: ReviewConfig,
) -> tuple[CheckResult, str | None]:
    commands = (
        (["git", "status", "--porcelain"], ""),
        (["git", "rev-parse", "--abbrev-ref", "HEAD"], "main"),
    )
    for argv, expected in commands:
        result = runner.run(argv)
        if result.returncode != 0 or result.timed_out or result.stdout.strip() != expected:
            return _open("source", "local-source-open"), None
    head = runner.run(["git", "rev-parse", "HEAD"])
    origin = runner.run(["git", "rev-parse", "refs/remotes/origin/main"])
    remote_main = runner.run(
        [
            "git",
            "ls-remote",
            "--exit-code",
            config.source_repository,
            "refs/heads/main",
        ]
    )
    head_revision = head.stdout.strip()
    if (
        head.returncode != 0
        or origin.returncode != 0
        or head.timed_out
        or origin.timed_out
        or remote_main.returncode != 0
        or remote_main.timed_out
        or head_revision != origin.stdout.strip()
        or head_revision != _remote_main_hash(remote_main.stdout)
        or re.fullmatch(r"[0-9a-f]{40}", head_revision) is None
    ):
        return _open("source", "local-source-open"), None
    ancestor = runner.run(
        ["git", "merge-base", "--is-ancestor", config.deployed_revision, "HEAD"]
    )
    runtime_diff = runner.run(
        [
            "git",
            "diff",
            "--quiet",
            f"{config.deployed_revision}..HEAD",
            "--",
            *RUNTIME_INPUT_PATHS,
        ]
    )
    remote = runner.run(["git", "remote", "get-url", "origin"])
    if (
        ancestor.returncode != 0
        or runtime_diff.returncode != 0
        or remote.returncode != 0
        or _canonical_repository(remote.stdout)
        != _canonical_repository(config.source_repository)
    ):
        return _open("source", "local-source-open"), None
    if repo_root != Path.cwd().resolve():
        return _open("source", "local-source-open"), None
    return _pass("source", "clean-synchronized"), head_revision


def check_archive(
    runner: CommandRunning,
    *,
    repo_root: Path,
    archive_path: Path,
    config: ReviewConfig,
) -> tuple[CheckResult, ArchiveContext | None]:
    try:
        archive = archive_path.resolve(strict=True)
        if not archive.is_relative_to(repo_root) or archive.name != config.archive_basename:
            raise ValueError
        app = archive / "Products/Applications/Wardrobe.app"
        info_path = app / "Info.plist"
        with info_path.open("rb") as handle:
            info = plistlib.load(handle)
        if not isinstance(info, dict):
            raise ValueError
        if (
            info.get("CFBundleShortVersionString") != config.marketing_version
            or info.get("CFBundleVersion") != config.build_number
            or info.get("DTPlatformName") != "iphoneos"
        ):
            raise ValueError
        archive_info_path = archive / "Info.plist"
        with archive_info_path.open("rb") as handle:
            archive_info = plistlib.load(handle)
        properties = archive_info.get("ApplicationProperties")
        if (
            not isinstance(properties, dict)
            or not str(properties.get("SigningIdentity", "")).startswith(
                "Apple Distribution:"
            )
        ):
            raise ValueError
        backend_url = str(info["BackendBaseURL"])
        privacy_url = str(info["PRIVACY_POLICY_URL"])
        support_url = str(info["SUPPORT_URL"])
        if not _archive_urls_match_policy(
            backend_url=backend_url,
            privacy_url=privacy_url,
            support_url=support_url,
            config=config,
        ):
            raise ValueError
        verifier = repo_root / "ios/scripts/verify-release-artifact.sh"
        verified = runner.run(
            [str(verifier), str(archive.parent), str(app)], timeout=120
        )
        if verified.returncode != 0 or verified.timed_out:
            raise ValueError
        app_binary = app / "Wardrobe"
        dsym_binary = (
            archive
            / "dSYMs/Wardrobe.app.dSYM/Contents/Resources/DWARF/Wardrobe"
        )
        app_arch = runner.run(["/usr/bin/lipo", "-archs", str(app_binary)])
        dsym_arch = runner.run(["/usr/bin/lipo", "-archs", str(dsym_binary)])
        app_uuid = runner.run(["/usr/bin/dwarfdump", "--uuid", str(app_binary)])
        dsym_uuid = runner.run(["/usr/bin/dwarfdump", "--uuid", str(dsym_binary)])
        code_detail = runner.run(
            ["/usr/bin/codesign", "-d", "--verbose=4", str(app)]
        )
        if (
            app_arch.returncode != 0
            or dsym_arch.returncode != 0
            or app_arch.stdout.strip() != "arm64"
            or dsym_arch.stdout.strip() != "arm64"
            or not _archive_identity_matches(
                code_detail=code_detail,
                app_uuid=app_uuid,
                dsym_uuid=dsym_uuid,
                config=config,
            )
        ):
            raise ValueError
        return (
            _pass("archive", "strict-artifact-match"),
            ArchiveContext(
                backend_url=backend_url.rstrip("/"),
                privacy_url=privacy_url,
                support_url=support_url,
            ),
        )
    except (OSError, KeyError, TypeError, ValueError, plistlib.InvalidFileException):
        return _open("archive", "archive-open"), None


def _dwarf_uuids(output: str) -> frozenset[str]:
    return frozenset(
        value.lower()
        for value in re.findall(
            r"UUID: ([0-9A-Fa-f-]{36}) \(arm64\)", output[:MAX_CAPTURE_BYTES]
        )
    )


def _archive_urls_match_policy(
    *,
    backend_url: str,
    privacy_url: str,
    support_url: str,
    config: ReviewConfig,
) -> bool:
    return (
        all(
            _is_public_https_url(value)
            for value in (backend_url, privacy_url, support_url)
        )
        and backend_url.rstrip("/") == config.backend_url
    )


def _code_directory_hash(output: CommandOutput) -> str | None:
    if output.returncode != 0 or output.timed_out:
        return None
    match = re.search(
        r"^CDHash=([0-9A-Fa-f]{40})$",
        output.stderr[:MAX_CAPTURE_BYTES],
        flags=re.MULTILINE,
    )
    return match.group(1).lower() if match is not None else None


def _archive_identity_matches(
    *,
    code_detail: CommandOutput,
    app_uuid: CommandOutput,
    dsym_uuid: CommandOutput,
    config: ReviewConfig,
) -> bool:
    expected_uuids = frozenset({config.dsym_uuid})
    return (
        _code_directory_hash(code_detail) == config.app_cdhash
        and app_uuid.returncode == 0
        and not app_uuid.timed_out
        and dsym_uuid.returncode == 0
        and not dsym_uuid.timed_out
        and _dwarf_uuids(app_uuid.stdout) == expected_uuids
        and _dwarf_uuids(dsym_uuid.stdout) == expected_uuids
    )


def collect_runtime(
    runner: CommandRunning,
    *,
    app: str,
    config: ReviewConfig,
) -> tuple[CheckResult, RuntimeContext | None]:
    releases = _dict_rows(
        _json_output(runner, ["flyctl", "releases", "--json", "--app", app])
    )
    machines = _dict_rows(
        _json_output(runner, ["flyctl", "machine", "list", "--json", "--app", app])
    )
    images = _dict_rows(
        _json_output(runner, ["flyctl", "image", "show", "--json", "--app", app])
    )
    checks_value = _json_output(
        runner, ["flyctl", "checks", "list", "--json", "--app", app]
    )
    if (
        releases is None
        or machines is None
        or images is None
        or not isinstance(checks_value, dict)
    ):
        return _open("fly_runtime", "runtime-evidence-open"), None
    try:
        if len(machines) != 1 or len(images) != 1:
            raise ValueError
        versioned: list[tuple[int, dict[str, Any]]] = []
        for row in releases:
            version = _release_version(row.get("Version"))
            if version is None:
                raise ValueError
            versioned.append((version, row))
        latest_version, release = max(versioned, key=lambda item: item[0])
        if (
            latest_version != config.fly_release_version
            or str(release.get("Status", "")).lower() != "complete"
            or release.get("InProgress") is not False
        ):
            raise ValueError
        machine = machines[0]
        if (
            machine.get("region") != config.region
            or machine.get("state") != "started"
            or machine.get("host_status") != "ok"
        ):
            raise ValueError
        machine_checks = _as_rows(machine.get("checks"))
        provider_groups = [_as_rows(rows) for rows in checks_value.values()]
        if not provider_groups or any(not rows for rows in provider_groups):
            raise ValueError
        provider_checks = [row for rows in provider_groups for row in rows]
        all_checks = machine_checks + provider_checks
        if not machine_checks or not provider_checks or any(
            str(row.get("status", "")).lower() != "passing" for row in all_checks
        ):
            raise ValueError
        machine_config = machine.get("config")
        if not isinstance(machine_config, dict):
            raise ValueError
        release_ref = release.get("ImageRef")
        # The current Fly JSON keeps the immutable Machine reference in
        # ``config.image``. The top-level ``image_ref`` field is provider-versioned
        # metadata and may be null or structured rather than a reference string.
        machine_ref = machine_config.get("image")
        release_digest = _digest_from_ref(release_ref)
        machine_digest = _digest_from_ref(machine_ref)
        image = images[0]
        image_digest = image.get("Digest")
        if (
            not isinstance(release_ref, str)
            or release_ref != machine_ref
            or release_digest is None
            or release_digest != machine_digest
            or image_digest != release_digest
        ):
            raise ValueError
        raw_labels = image.get("Labels")
        if isinstance(raw_labels, str):
            labels = json.loads(raw_labels)
        else:
            labels = raw_labels
        if not isinstance(labels, dict):
            raise ValueError
        if (
            labels.get("org.opencontainers.image.revision")
            != config.deployed_revision
            or _canonical_repository(labels.get("org.opencontainers.image.source"))
            != _canonical_repository(config.source_repository)
        ):
            raise ValueError
        return (
            _pass("fly_runtime", "exact-healthy-runtime"),
            RuntimeContext(
                app=app,
                machine_id=str(machine["id"]),
                image_ref=release_ref,
                machine_config=machine_config,
            ),
        )
    except (KeyError, TypeError, ValueError, json.JSONDecodeError):
        return _open("fly_runtime", "runtime-evidence-open"), None


def check_configuration(
    runner: CommandRunning,
    *,
    app: str,
    local_fly: dict[str, Any],
    runtime: RuntimeContext | None,
    config: ReviewConfig,
) -> CheckResult:
    live = _json_output(runner, ["flyctl", "config", "show", "--app", app])
    secrets = _dict_rows(
        _json_output(runner, ["flyctl", "secrets", "list", "--json", "--app", app])
    )
    if not isinstance(live, dict) or secrets is None or runtime is None:
        return _open("fly_configuration", "configuration-evidence-open")
    try:
        local_env = local_fly["env"]
        live_env = live["env"]
        machine_env = runtime.machine_config["env"]
        if not all(isinstance(value, dict) for value in (local_env, live_env, machine_env)):
            raise ValueError
        expected_values = {
            "ENVIRONMENT": "production",
            "AUTH_MODE": "app_attest",
            "APP_ATTEST_ENVIRONMENT": "production",
            "APP_ATTEST_DATABASE_PATH": "/data/app-attest/auth.sqlite3",
            "APP_ATTEST_APP_ID_PREFIX": config.app_attest_app_id_prefix,
            "APP_ATTEST_BUNDLE_ID": config.app_attest_bundle_id,
            "APP_ATTEST_ALLOWED_VALIDATION_CATEGORIES": ",".join(
                config.validation_categories
            ),
            "APP_ATTEST_ALLOWED_BUNDLE_VERSIONS": ",".join(config.bundle_versions),
        }
        expected_machine_values = expected_values | {
            "FLY_PROCESS_GROUP": "app",
            "PRIMARY_REGION": config.region,
        }
        if (
            local_env != expected_values
            or live_env != expected_values
            or machine_env != expected_machine_values
        ):
            raise ValueError
        if live.get("primary_region") != config.region:
            raise ValueError
        local_service = local_fly["http_service"]
        live_service = live["http_service"]
        if not isinstance(local_service, dict) or not isinstance(live_service, dict):
            raise ValueError
        health_check = {
            "interval": "30s",
            "timeout": "5s",
            "grace_period": "10s",
            "method": "GET",
            "path": "/health",
        }
        expected_local_service = {
            "internal_port": 8080,
            "force_https": True,
            "auto_stop_machines": "stop",
            "auto_start_machines": True,
            "min_machines_running": 1,
            "checks": [health_check],
        }
        expected_live_service = expected_local_service | {
            "auto_stop_machines": True
        }
        expected_machine_service = {
            "protocol": "tcp",
            "internal_port": 8080,
            "autostop": True,
            "autostart": True,
            "min_machines_running": 1,
            "ports": [
                {"port": 80, "handlers": ["http"], "force_https": True},
                {"port": 443, "handlers": ["http", "tls"]},
            ],
            "checks": [{"type": "http"} | health_check],
            "force_instance_key": None,
        }
        live_services = live.get("services")
        has_no_extra_live_services = (
            "services" not in live
            or live_services is None
            or (isinstance(live_services, list) and not live_services)
        )
        if (
            local_service != expected_local_service
            or live_service != expected_live_service
            or runtime.machine_config.get("services") != [expected_machine_service]
            or local_fly.get("vm")
            != [{"size": "shared-cpu-1x", "memory": "512mb"}]
            or live.get("vm")
            != [{"size": "shared-cpu-1x", "memory": "512mb"}]
            or runtime.machine_config.get("guest")
            != {"cpu_kind": "shared", "cpus": 1, "memory_mb": 512}
            or runtime.machine_config.get("restart")
            != {"policy": "on-failure", "max_retries": 10}
            or runtime.machine_config.get("auto_destroy") is not None
            or runtime.machine_config.get("init") != {}
            or local_fly.get("build") != {}
            or live.get("build") is not None
            or "services" in local_fly
            or not has_no_extra_live_services
        ):
            raise ValueError
        local_mounts = _as_rows(local_fly.get("mounts"))
        live_mounts = _as_rows(live.get("mounts"))
        if (
            len(local_mounts) != 1
            or len(live_mounts) != 1
            or local_mounts[0]
            != {"source": "wardrobe_auth_data", "destination": "/data"}
            or live_mounts[0] != local_mounts[0]
        ):
            raise ValueError
        secret_state: dict[str, str] = {}
        for row in secrets:
            name = row.get("name")
            status = row.get("status")
            if (
                not isinstance(name, str)
                or not isinstance(status, str)
                or name in secret_state
            ):
                raise ValueError
            secret_state[name] = status.lower()
        if set(secret_state) != set(config.required_secret_names) or any(
            status != "deployed" for status in secret_state.values()
        ):
            raise ValueError
        return _pass("fly_configuration", "app-attest-only")
    except (KeyError, TypeError, ValueError):
        return _open("fly_configuration", "configuration-evidence-open")


def collect_storage(
    runner: CommandRunning,
    *,
    app: str,
    runtime: RuntimeContext | None,
    config: ReviewConfig,
    now: datetime,
) -> tuple[CheckResult, StorageContext | None]:
    volumes = _dict_rows(
        _json_output(runner, ["flyctl", "volumes", "list", "--json", "--app", app])
    )
    if volumes is None or runtime is None or len(volumes) != 1:
        return _open("snapshot", "snapshot-evidence-open"), None
    try:
        volume = volumes[0]
        if (
            volume.get("encrypted") is not True
            or volume.get("state") != "created"
            or volume.get("region") != config.region
            or volume.get("auto_backup_enabled") is not True
            or volume.get("snapshot_retention") != 14
            or volume.get("attached_machine_id") != runtime.machine_id
        ):
            raise ValueError
        volume_id = str(volume["id"])
        machine_mounts = _as_rows(runtime.machine_config.get("mounts"))
        if machine_mounts != [
            {
                "volume": volume_id,
                "path": "/data",
                "encrypted": True,
                "size_gb": 1,
                "name": "wardrobe_auth_data",
            }
        ]:
            raise ValueError
        snapshots = _dict_rows(
            _json_output(
                runner,
                [
                    "flyctl",
                    "volumes",
                    "snapshots",
                    "list",
                    volume_id,
                    "--json",
                    "--app",
                    app,
                ],
            )
        )
        if not snapshots:
            raise ValueError
        parsed: list[tuple[datetime, dict[str, Any]]] = []
        for snapshot in snapshots:
            created_at = _parse_utc(snapshot.get("created_at"))
            if created_at is None:
                raise ValueError
            parsed.append((created_at, snapshot))
            if snapshot.get("status") != "created" or snapshot.get("retention_days") != 14:
                raise ValueError
        newest_at, newest = max(parsed, key=lambda item: item[0])
        age = now.astimezone(UTC) - newest_at
        if age < timedelta(0) or age > SNAPSHOT_MAX_AGE:
            raise ValueError
        metadata = SnapshotMetadata(
            created_at=newest_at,
            status=str(newest["status"]),
            retention_days=int(newest["retention_days"]),
        )
        return (
            _pass("snapshot", "automatic-14-day-fresh"),
            StorageContext(volume_id=volume_id, snapshot=metadata),
        )
    except (KeyError, TypeError, ValueError):
        return _open("snapshot", "snapshot-evidence-open"), None


_REMOTE_DIAGNOSTIC = r"""
import json
import os
import sqlite3
import stat
import time
from pathlib import Path
from urllib.parse import quote

from app.auth.store import AuthStore

database = Path(os.environ["APP_ATTEST_DATABASE_PATH"])
uri = "file:" + quote(str(database), safe="/") + "?mode=ro"
connection = sqlite3.connect(uri, uri=True)
connection.row_factory = sqlite3.Row
connection.execute("PRAGMA query_only=ON")
connection.execute("PRAGMA foreign_keys=ON")
now = int(time.time())
tables = {
    str(row[0])
    for row in connection.execute(
        "SELECT name FROM sqlite_schema "
        "WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    )
}
indexes = {
    str(row[0])
    for row in connection.execute(
        "SELECT name FROM sqlite_schema "
        "WHERE type='index' AND name NOT LIKE 'sqlite_%'"
    )
}
unexpected_objects = connection.execute(
    "SELECT COUNT(*) FROM sqlite_schema "
    "WHERE type IN ('trigger','view') AND name NOT LIKE 'sqlite_%'"
).fetchone()[0]
try:
    AuthStore._verify_expected_auth_schema(connection)
    exact_schema = True
except (RuntimeError, sqlite3.Error):
    exact_schema = False
database_stat = database.stat()
parent_stat = database.parent.stat()
runtime_processes = []
for process_path in Path("/proc").iterdir():
    if not process_path.name.isdigit():
        continue
    try:
        candidate_command = (process_path / "cmdline").read_bytes().replace(
            b"\x00", b" "
        )
    except OSError:
        continue
    if b"/app/.venv/bin/uvicorn" in candidate_command and b"app.main:app" in candidate_command:
        runtime_processes.append((process_path, candidate_command))
process_status = (
    (runtime_processes[0][0] / "status").read_text(encoding="utf-8")
    if len(runtime_processes) == 1
    else ""
)
process_command = runtime_processes[0][1] if len(runtime_processes) == 1 else b""
process_uid = any(
    line.split()[1:] == ["10001", "10001", "10001", "10001"]
    for line in process_status.splitlines()
    if line.startswith("Uid:")
)
process_no_new_privileges = any(
    line.split()[1:] == ["1"]
    for line in process_status.splitlines()
    if line.startswith("NoNewPrivs:")
)
process_uvicorn = b"uvicorn" in process_command and b"app.main:app" in process_command
process_no_access_log = b"--no-access-log" in process_command
process_logging_config = b"/app/uvicorn-logging.json" in process_command
filesystem = os.statvfs("/data")
total_bytes = filesystem.f_blocks * filesystem.f_frsize
available_bytes = filesystem.f_bavail * filesystem.f_frsize
used_percent = 100.0 if total_bytes <= 0 else (total_bytes - available_bytes) * 100 / total_bytes
result = {
    "diagnostic_version": 1,
    "query_only": connection.execute("PRAGMA query_only").fetchone()[0],
    "foreign_keys": connection.execute("PRAGMA foreign_keys").fetchone()[0],
    "secure_delete": connection.execute("PRAGMA secure_delete").fetchone()[0],
    "synchronous": connection.execute("PRAGMA synchronous").fetchone()[0],
    "journal_mode": str(connection.execute("PRAGMA journal_mode").fetchone()[0]).lower(),
    "schema_version": connection.execute("PRAGMA user_version").fetchone()[0],
    "integrity_ok": connection.execute("PRAGMA integrity_check").fetchone()[0] == "ok",
    "foreign_key_errors": len(connection.execute("PRAGMA foreign_key_check").fetchall()),
    "expected_tables": tables == {"challenges", "installations", "rate_windows", "sessions"},
    "expected_indexes": indexes == {
        "challenges_expiry_idx",
        "installations_last_seen_idx",
        "installations_revoked_idx",
        "rate_windows_expiry_idx",
        "sessions_expiry_idx",
        "sessions_token_hash_idx",
    },
    "exact_schema": exact_schema,
    "unexpected_objects": unexpected_objects,
    "database_security": (
        stat.S_ISREG(database_stat.st_mode)
        and database_stat.st_nlink == 1
        and database_stat.st_uid == 10001
        and database_stat.st_gid == 10001
        and stat.S_IMODE(database_stat.st_mode) == 0o600
        and parent_stat.st_uid == 10001
        and parent_stat.st_gid == 10001
        and stat.S_IMODE(parent_stat.st_mode) == 0o700
        and not database.is_symlink()
        and not database.parent.is_symlink()
    ),
    "process_runtime": (
        len(runtime_processes) == 1
        and process_uid
        and process_no_new_privileges
        and process_uvicorn
        and process_no_access_log
        and process_logging_config
    ),
    "process_uid": process_uid,
    "process_no_new_privileges": process_no_new_privileges,
    "process_uvicorn": process_uvicorn,
    "process_no_access_log": process_no_access_log,
    "process_logging_config": process_logging_config,
    "active_installations": connection.execute(
        "SELECT COUNT(*) FROM installations WHERE revoked_at IS NULL"
    ).fetchone()[0],
    "active_sessions": connection.execute(
        "SELECT COUNT(*) FROM sessions WHERE revoked_at IS NULL AND expires_at > ?",
        (now,),
    ).fetchone()[0],
    "pending_challenges": connection.execute(
        "SELECT COUNT(*) FROM challenges "
        "WHERE state IN ('issued','processing') AND expires_at > ?",
        (now,),
    ).fetchone()[0],
    "failed_challenges": connection.execute(
        "SELECT COUNT(*) FROM challenges WHERE state='failed'"
    ).fetchone()[0],
    "rate_windows": connection.execute(
        "SELECT COUNT(*) FROM rate_windows WHERE expires_at > ?", (now,)
    ).fetchone()[0],
    "used_percent": used_percent,
}
print(json.dumps(result, separators=(",", ":")))
"""


def collect_diagnostics(
    runner: CommandRunning,
    *,
    runtime: RuntimeContext | None,
    config: ReviewConfig,
) -> tuple[CheckResult, CheckResult, CheckResult]:
    fallback = (
        _open("auth_store", "auth-store-evidence-open"),
        _open("auth_aggregate", "auth-aggregate-open"),
        _open("volume", "volume-evidence-open"),
    )
    if runtime is None:
        return fallback
    encoded = base64.b64encode(_REMOTE_DIAGNOSTIC.encode("utf-8")).decode("ascii")
    remote_command = (
        "/app/.venv/bin/python -c \"import base64;"
        f"exec(base64.b64decode('{encoded}'))\""
    )
    output = runner.run(
        [
            "flyctl",
            "ssh",
            "console",
            "--app",
            runtime.app,
            "--machine",
            runtime.machine_id,
            "--quiet",
            "--command",
            remote_command,
        ],
        timeout=45,
    )
    if output.returncode != 0 or output.timed_out:
        return fallback
    diagnostic: dict[str, Any] | None = None
    for line in reversed(output.stdout.splitlines()):
        try:
            candidate = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(candidate, dict):
            diagnostic = candidate
            break
    if diagnostic is None:
        return fallback
    store_ok = (
        diagnostic.get("diagnostic_version") == 1
        and diagnostic.get("query_only") == 1
        and diagnostic.get("foreign_keys") == 1
        and diagnostic.get("secure_delete") == 1
        and diagnostic.get("synchronous") == 2
        and diagnostic.get("journal_mode") == "wal"
        and diagnostic.get("schema_version") == config.auth_schema_version
        and diagnostic.get("integrity_ok") is True
        and diagnostic.get("foreign_key_errors") == 0
        and diagnostic.get("expected_tables") is True
        and diagnostic.get("expected_indexes") is True
        and diagnostic.get("exact_schema") is True
        and diagnostic.get("unexpected_objects") == 0
        and diagnostic.get("database_security") is True
        and diagnostic.get("process_runtime") is True
    )
    auth_store = (
        _pass("auth_store", "schema-integrity-and-runtime-guards")
        if store_ok
        else _open("auth_store", "auth-store-evidence-open")
    )
    aggregate_values = tuple(
        diagnostic.get(key)
        for key in (
            "active_installations",
            "active_sessions",
            "pending_challenges",
            "failed_challenges",
            "rate_windows",
        )
    )
    aggregates_ok = (
        all(
            isinstance(value, int)
            and not isinstance(value, bool)
            and value >= 0
            for value in aggregate_values
        )
        and aggregate_values[0] <= 1
        and aggregate_values[1] <= 1
        and aggregate_values[1] <= aggregate_values[0]
        and aggregate_values[2] == 0
        and aggregate_values[3] == 0
        and aggregate_values[4] <= 552
    )
    auth_aggregate = (
        _pass("auth_aggregate", "single-user-band")
        if aggregates_ok
        else _open("auth_aggregate", "auth-aggregate-open")
    )
    raw_usage = diagnostic.get("used_percent")
    if (
        not isinstance(raw_usage, (int, float))
        or isinstance(raw_usage, bool)
        or not 0 <= float(raw_usage) <= 100
    ):
        volume = _open("volume", "volume-evidence-open")
    elif float(raw_usage) < 70:
        volume = _pass("volume", "below-70-percent")
    elif float(raw_usage) < 85:
        volume = _warning("volume", "70-to-84-percent")
    else:
        volume = _open("volume", "85-percent-or-more")
    return auth_store, auth_aggregate, volume


_AUTH_FAILURE_MARKERS = (
    "event=assertion_rejected",
    "event=bridge_bearer_rejected",
    "event=deletion_rejected",
    "event=installation_rejected",
    "event=rate_limit_exceeded",
    "event=registration_rejected",
)
_SERVICE_FAILURE_MARKERS = (
    "anthropic_concurrency_rejected",
    "anthropic_request_failed",
    "event=auth_maintenance_failed",
    "stylist_failure",
    "Tool input failed schema validation",
    "unhandled_api_error",
)


def check_bounded_events(
    runner: CommandRunning,
    *,
    app: str,
    now: datetime,
) -> CheckResult:
    output = runner.run(
        ["flyctl", "logs", "--no-tail", "--json", "--app", app],
        timeout=LOG_TIMEOUT_SECONDS,
    )
    if output.returncode != 0 or output.timed_out:
        return _open("bounded_events", "event-evidence-open")
    rows = _json_object_stream(output.stdout)
    if not rows:
        return _open("bounded_events", "event-evidence-open")
    auth_failures = 0
    service_failures = 0
    current_window_rows = 0
    for row in rows:
        message = row.get("message", row.get("msg"))
        if not isinstance(message, str):
            return _open("bounded_events", "event-evidence-open")
        timestamp = _parse_utc(row.get("timestamp", row.get("time")))
        if timestamp is None:
            return _open("bounded_events", "event-evidence-open")
        age = now.astimezone(UTC) - timestamp
        if age < timedelta(0):
            return _open("bounded_events", "event-evidence-open")
        is_current = age <= EVENT_WINDOW
        current_window_rows += int(is_current)
        is_auth = any(marker in message for marker in _AUTH_FAILURE_MARKERS)
        is_service = any(marker in message for marker in _SERVICE_FAILURE_MARKERS)
        if not is_auth and not is_service:
            continue
        if is_current:
            auth_failures += int(is_auth)
            service_failures += int(is_service)
    if current_window_rows == 0:
        return _open("bounded_events", "event-evidence-open")
    if auth_failures >= 5 or service_failures >= 3:
        return _open("bounded_events", "failure-cluster-open")
    return _pass("bounded_events", "below-policy-threshold")


def check_public_backend(
    getter: HTTPGetting,
    *,
    archive: ArchiveContext | None,
    config: ReviewConfig,
) -> CheckResult:
    if archive is None:
        return _open("public_backend", "public-backend-open")
    health = getter.get(urljoin(archive.backend_url + "/", "health"))
    openapi = getter.get(urljoin(archive.backend_url + "/", "openapi.json"))
    removed = getter.get(urljoin(archive.backend_url + "/", "extract"))
    if health is None or openapi is None or removed is None:
        return _open("public_backend", "public-backend-open")
    try:
        health_body = json.loads(health.body)
        openapi_body = json.loads(openapi.body)
        paths = openapi_body["paths"]
        if (
            health.status != 200
            or not _same_https_host(health.final_url, archive.backend_url)
            or health_body != {"status": "ok", "environment": "production"}
            or openapi.status != 200
            or not _same_https_host(openapi.final_url, archive.backend_url)
            or not isinstance(paths, dict)
            or set(paths) != set(config.expected_routes)
            or removed.status != 404
            or not _same_https_host(removed.final_url, archive.backend_url)
        ):
            raise ValueError
        return _pass("public_backend", "health-and-routes")
    except (KeyError, TypeError, ValueError, json.JSONDecodeError, UnicodeError):
        return _open("public_backend", "public-backend-open")


class _PageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.text: list[str] = []
        self.hrefs: list[str] = []

    def handle_data(self, data: str) -> None:
        self.text.append(data)

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag.lower() != "a":
            return
        for name, value in attrs:
            if name.lower() == "href" and isinstance(value, str):
                self.hrefs.append(value)


def _normalized_page_url(value: str) -> str | None:
    if not _is_public_https_url(value):
        return None
    parts = urlsplit(value)
    path = parts.path or "/"
    if not path.endswith("/"):
        path += "/"
    return urlunsplit(("https", parts.netloc.lower(), path, "", ""))


def _same_https_host(actual: str, expected: str) -> bool:
    try:
        actual_parts = urlsplit(actual)
        expected_parts = urlsplit(expected)
    except ValueError:
        return False
    return (
        actual_parts.scheme == "https"
        and expected_parts.scheme == "https"
        and actual_parts.hostname == expected_parts.hostname
    )


def check_public_pages(
    getter: HTTPGetting,
    *,
    archive: ArchiveContext | None,
    config: ReviewConfig,
) -> CheckResult:
    if archive is None:
        return _open("public_pages", "public-pages-open")
    urls = {
        "support": archive.support_url,
        "privacy": archive.privacy_url,
        "terms": config.terms_url,
    }
    normalized = {name: _normalized_page_url(url) for name, url in urls.items()}
    if any(value is None for value in normalized.values()):
        return _open("public_pages", "public-pages-open")
    parsed: dict[str, tuple[str, set[str], set[str]]] = {}
    for name, url in urls.items():
        response = getter.get(url)
        if (
            response is None
            or response.status != 200
            or not _same_https_host(response.final_url, url)
        ):
            return _open("public_pages", "public-pages-open")
        try:
            html = response.body.decode("utf-8")
        except UnicodeError:
            return _open("public_pages", "public-pages-open")
        parser = _PageParser()
        parser.feed(html)
        text = " ".join(parser.text).lower()
        links = {
            target
            for href in parser.hrefs
            if (target := _normalized_page_url(urljoin(response.final_url, href)))
            is not None
        }
        mail = {
            href.lower()
            for href in parser.hrefs
            if href.lower().startswith("mailto:")
        }
        parsed[name] = (text, links, mail)
    forbidden = ("connect your gmail", "gmail.readonly", "receipt import", "sign in with google")
    if any(marker in text for text, _, _ in parsed.values() for marker in forbidden):
        return _open("public_pages", "public-pages-open")
    support_text, support_links, support_mail = parsed["support"]
    privacy_text, privacy_links, privacy_mail = parsed["privacy"]
    terms_text, terms_links, terms_mail = parsed["terms"]
    contact = "mailto:contact@tth.dev"
    if (
        not all(
            marker in support_text
            for marker in (
                "wardrobe stylist",
                "delete server security data",
                "two business days",
            )
        )
        or not all(
            marker in privacy_text
            for marker in (
                "wardrobe stylist",
                "app attest",
                "anthropic",
                "fly.io",
                "rolling 14-day snapshots",
            )
        )
        or "wardrobe stylist" not in terms_text
        or "terms" not in terms_text
        or contact not in support_mail | privacy_mail | terms_mail
    ):
        return _open("public_pages", "public-pages-open")
    expected_link_sets = {
        "support": {normalized["privacy"], normalized["terms"]},
        "privacy": {normalized["support"], normalized["terms"]},
        "terms": {normalized["support"], normalized["privacy"]},
    }
    actual_links = {
        "support": support_links,
        "privacy": privacy_links,
        "terms": terms_links,
    }
    if any(
        not {str(value) for value in expected}.issubset(actual_links[name])
        for name, expected in expected_link_sets.items()
    ):
        return _open("public_pages", "public-pages-open")
    return _pass("public_pages", "support-privacy-terms")


def check_anthropic_status(
    getter: HTTPGetting,
    *,
    config: ReviewConfig,
) -> CheckResult:
    response = getter.get(config.anthropic_status_url)
    if (
        response is None
        or response.status != 200
        or not _same_https_host(response.final_url, config.anthropic_status_url)
    ):
        return _open("anthropic_status", "public-status-open")
    try:
        body = json.loads(response.body)
        if body["status"]["indicator"] != "none":
            raise ValueError
        return _pass("anthropic_status", "public-status-operational")
    except (KeyError, TypeError, ValueError, json.JSONDecodeError, UnicodeError):
        return _open("anthropic_status", "public-status-open")


def check_recovery_scan(
    runner: CommandRunning,
    *,
    runtime: RuntimeContext | None,
    refresh_registry_auth: bool,
) -> CheckResult:
    if runtime is None or not refresh_registry_auth:
        return _open("recovery_scan", "recovery-scan-open")
    with tempfile.TemporaryDirectory(prefix="wardrobe-registry-auth-") as directory:
        os.chmod(directory, 0o700)
        docker_env = dict(os.environ)
        docker_env["DOCKER_CONFIG"] = directory
        authenticated = runner.run(
            ["flyctl", "auth", "docker"], timeout=45, env=docker_env
        )
        if authenticated.returncode != 0 or authenticated.timed_out:
            return _open("recovery_scan", "recovery-scan-open")
        manifest_inspected = runner.run(
            [
                "docker",
                "buildx",
                "imagetools",
                "inspect",
                "--format",
                "{{json .Manifest}}",
                runtime.image_ref,
            ],
            timeout=60,
            env=docker_env,
        )
        image_inspected = runner.run(
            [
                "docker",
                "buildx",
                "imagetools",
                "inspect",
                "--format",
                "{{json .Image}}",
                runtime.image_ref,
            ],
            timeout=60,
            env=docker_env,
        )
        if (
            manifest_inspected.returncode != 0
            or manifest_inspected.timed_out
            or image_inspected.returncode != 0
            or image_inspected.timed_out
        ):
            return _open("recovery_scan", "recovery-scan-open")
        try:
            manifest = json.loads(manifest_inspected.stdout)
            image = json.loads(image_inspected.stdout)
            if (
                not isinstance(manifest, dict)
                or not isinstance(image, dict)
                or image.get("os") != "linux"
                or image.get("architecture") != "amd64"
                or manifest.get("digest") != _digest_from_ref(runtime.image_ref)
            ):
                raise ValueError
        except (KeyError, TypeError, ValueError, json.JSONDecodeError):
            return _open("recovery_scan", "recovery-scan-open")
        scanned = runner.run(
            [
                "docker",
                "scout",
                "cves",
                "--only-severity",
                "critical,high",
                "--exit-code",
                "--platform",
                "linux/amd64",
                "registry://" + runtime.image_ref,
            ],
            timeout=180,
            env=docker_env,
        )
        if scanned.returncode != 0 or scanned.timed_out:
            return _open("recovery_scan", "recovery-scan-open")
    return _pass("recovery_scan", "exact-linux-amd64-zero-high-critical")


def manual_results(
    *,
    evidence_path: Path | None,
    config: ReviewConfig,
    now: datetime,
) -> tuple[CheckResult, CheckResult, CheckResult]:
    required = (
        _open("official_fly_metrics", "manual-review-required"),
        _open("anthropic_console", "manual-review-required"),
        _open("app_store_connect", "manual-review-required"),
    )
    if evidence_path is None:
        return required
    try:
        raw = tomllib.loads(evidence_path.read_text(encoding="utf-8"))
        if set(raw) != {
            "checked_at_utc",
            "marketing_version",
            "build_number",
            "archive_cdhash",
            "deployed_revision",
            "official_fly_metrics",
            "anthropic_console",
            "app_store_connect",
        }:
            raise ValueError
        if (
            raw["marketing_version"] != config.marketing_version
            or raw["build_number"] != config.build_number
            or raw["archive_cdhash"] != config.app_cdhash
            or raw["deployed_revision"] != config.deployed_revision
        ):
            raise ValueError
        checked_at = _parse_utc(raw["checked_at_utc"])
        if checked_at is None:
            raise ValueError
        age = now.astimezone(UTC) - checked_at
        if age < timedelta(0) or age > config.manual_evidence_max_age:
            raise ValueError
        metric = str(raw["official_fly_metrics"]).lower()
        anthropic = str(raw["anthropic_console"]).lower()
        app_store = str(raw["app_store_connect"]).lower()
        if metric != "pass" or app_store != "pass" or anthropic not in {
            "pass",
            "warning",
        }:
            raise ValueError
        return (
            _pass("official_fly_metrics", "fresh-signed-in-pass"),
            (
                _pass("anthropic_console", "fresh-signed-in-pass")
                if anthropic == "pass"
                else _warning(
                    "anthropic_console", "fresh-signed-in-warning"
                )
            ),
            _pass("app_store_connect", "fresh-signed-in-pass"),
        )
    except (OSError, UnicodeError, tomllib.TOMLDecodeError, ValueError, TypeError):
        return (
            _open("official_fly_metrics", "manual-review-open"),
            _open("anthropic_console", "manual-review-open"),
            _open("app_store_connect", "manual-review-open"),
        )


def _load_local_fly(path: Path) -> tuple[dict[str, Any], str]:
    try:
        value = tomllib.loads(path.read_text(encoding="utf-8"))
        app = value.get("app")
        if not isinstance(value, dict) or not isinstance(app, str) or not app.strip():
            raise ValueError
        return value, app.strip()
    except (OSError, UnicodeError, tomllib.TOMLDecodeError, ValueError, TypeError):
        raise ReviewConfigurationError("local Fly configuration is invalid") from None


def _fly_binding_matches(*, app: str, config: ReviewConfig) -> bool:
    parts = urlsplit(config.backend_url)
    return (
        app == config.fly_app
        and parts.hostname == f"{app}.fly.dev"
        and parts.port in (None, 443)
        and parts.path in ("", "/")
        and not parts.query
        and not parts.fragment
    )


def run_review(
    *,
    repo_root: Path,
    archive_path: Path,
    evidence_path: Path | None,
    refresh_registry_auth: bool,
    runner: CommandRunning,
    getter: HTTPGetting,
    clock: Callable[[], datetime],
) -> ReviewReport:
    config = ReviewConfig.load(repo_root / "backend/production-operations.toml")
    local_fly, app = _load_local_fly(repo_root / "backend/fly.toml")
    if not _fly_binding_matches(app=app, config=config):
        raise ReviewConfigurationError(
            "locked Fly application and backend URL do not match"
        )
    source_at_start, start_revision = check_source(
        runner, repo_root=repo_root, config=config
    )
    archive_result, archive = check_archive(
        runner,
        repo_root=repo_root,
        archive_path=archive_path,
        config=config,
    )
    runtime_result, runtime = collect_runtime(
        runner, app=app, config=config
    )
    configuration = check_configuration(
        runner,
        app=app,
        local_fly=local_fly,
        runtime=runtime,
        config=config,
    )
    snapshot_result, storage = collect_storage(
        runner,
        app=app,
        runtime=runtime,
        config=config,
        now=_clock_utc(clock),
    )
    auth_store, auth_aggregate, volume = collect_diagnostics(
        runner, runtime=runtime, config=config
    )
    bounded_events = check_bounded_events(
        runner, app=app, now=_clock_utc(clock)
    )
    public_backend = check_public_backend(getter, archive=archive, config=config)
    public_pages = check_public_pages(getter, archive=archive, config=config)
    anthropic_status = check_anthropic_status(getter, config=config)
    recovery_scan = check_recovery_scan(
        runner,
        runtime=runtime,
        refresh_registry_auth=refresh_registry_auth,
    )
    source_at_completion, completion_revision = check_source(
        runner, repo_root=repo_root, config=config
    )
    source = (
        source_at_start
        if source_at_start.status is Status.PASS
        and source_at_completion.status is Status.PASS
        and start_revision is not None
        and start_revision == completion_revision
        else _open("source", "local-source-open")
    )
    completed_at = _clock_utc(clock)
    manual = manual_results(
        evidence_path=evidence_path,
        config=config,
        now=completed_at,
    )
    by_name = {
        result.name: result
        for result in (
            source,
            archive_result,
            runtime_result,
            configuration,
            auth_store,
            auth_aggregate,
            volume,
            snapshot_result,
            bounded_events,
            public_backend,
            public_pages,
            anthropic_status,
            recovery_scan,
            *manual,
        )
    }
    return ReviewReport(
        checked_at=completed_at,
        results=tuple(by_name[name] for name in CHECK_ORDER),
        snapshot=storage.snapshot if storage is not None else None,
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Run the redacted Wardrobe production pre-upload preflight. "
            "This command never uploads or mutates provider resources."
        )
    )
    parser.add_argument(
        "--archive",
        type=Path,
        help="exact verified xcarchive; defaults to the locked candidate",
    )
    parser.add_argument(
        "--manual-evidence",
        type=Path,
        help="fresh fixed-field TOML from the signed-in manual checks",
    )
    parser.add_argument(
        "--refresh-registry-auth",
        action="store_true",
        help=(
            "refresh Fly registry credentials in an ephemeral Docker config before "
            "the exact recovery scan; required for a passing preflight"
        ),
    )
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv[1:])
    repo_root = Path(__file__).resolve().parent.parent
    try:
        config = ReviewConfig.load(repo_root / "backend/production-operations.toml")
        archive_path = args.archive or (
            repo_root
            / "ios/DerivedData/ReleaseValidation"
            / config.archive_basename
        )
        report = run_review(
            repo_root=repo_root,
            archive_path=archive_path,
            evidence_path=args.manual_evidence,
            refresh_registry_auth=bool(args.refresh_registry_auth),
            runner=SubprocessRunner(),
            getter=UrllibHTTPGetter(),
            clock=lambda: datetime.now(UTC),
        )
    except ReviewConfigurationError:
        print(
            "Production operational preflight could not load trusted local configuration.",
            file=sys.stderr,
        )
        return 2
    print(report.render())
    if not report.passed:
        print(
            "Production operational preflight remains open; no upload was attempted.",
            file=sys.stderr,
        )
        return 1
    print(
        "Production operational evidence passed; explicit owner upload approval is still required.",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
