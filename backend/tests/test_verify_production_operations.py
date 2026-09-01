from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import time
from collections.abc import Sequence
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import pytest

SCRIPT = Path(__file__).parents[1] / "verify_production_operations.py"
SPEC = importlib.util.spec_from_file_location("verify_production_operations", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)

NOW = datetime(2026, 9, 1, 12, 0, tzinfo=UTC)
DIGEST = "sha256:" + "a" * 64
IMAGE_REF = "registry.invalid/private-image@" + DIGEST
APP_CDHASH = "c" * 40
DSYM_UUID = "81849d80-b84a-379d-b84f-7b13d580c385"
APP = "private-app-canary"
MACHINE = "private-machine-canary"
VOLUME = "private-volume-canary"
SECRET_CANARY = "SECRET_CANARY_DO_NOT_RENDER"


class FakeRunner:
    def __init__(self, responses: dict[tuple[str, ...], Any] | None = None) -> None:
        self.responses = responses or {}
        self.calls: list[tuple[str, ...]] = []

    def run(
        self,
        argv: Sequence[str],
        *,
        timeout: int = MODULE.COMMAND_TIMEOUT_SECONDS,
        env: dict[str, str] | None = None,
    ) -> Any:
        del timeout, env
        key = tuple(argv)
        self.calls.append(key)
        value = self.responses.get(key)
        if callable(value):
            value = value()
        if value is None:
            return MODULE.CommandOutput(returncode=127, stderr=SECRET_CANARY)
        if isinstance(value, MODULE.CommandOutput):
            return value
        return MODULE.CommandOutput(returncode=0, stdout=str(value))


class FakeGetter:
    def __init__(self, responses: dict[str, Any]) -> None:
        self.responses = responses
        self.calls: list[str] = []

    def get(self, url: str, *, timeout: int = 15) -> Any:
        del timeout
        self.calls.append(url)
        return self.responses.get(url)


def output(value: object) -> Any:
    return MODULE.CommandOutput(returncode=0, stdout=json.dumps(value))


def test_subprocess_runner_uses_devnull_stdin_and_bounded_capture() -> None:
    runner = MODULE.SubprocessRunner()
    stdin_result = runner.run(
        [sys.executable, "-c", "import sys; print(len(sys.stdin.read()))"],
        timeout=5,
    )
    overflow_result = runner.run(
        [
            sys.executable,
            "-c",
            (
                "import sys; sys.stdout.buffer.write(b'x' * "
                f"{MODULE.MAX_CAPTURE_BYTES + 1})"
            ),
        ],
        timeout=5,
    )

    assert stdin_result.returncode == 0
    assert stdin_result.stdout == "0\n"
    assert overflow_result.returncode == 125
    assert len(overflow_result.stdout) <= MODULE.MAX_CAPTURE_BYTES


def test_subprocess_runner_bounds_inherited_pipe_timeout() -> None:
    runner = MODULE.SubprocessRunner()
    child = (
        "import subprocess, sys; "
        f"subprocess.Popen([{sys.executable!r}, '-c', "
        "'import time; time.sleep(30)'], stdout=sys.stdout, stderr=sys.stderr)"
    )
    started = time.monotonic()

    result = runner.run([sys.executable, "-c", child], timeout=1)

    assert result.timed_out is True
    assert time.monotonic() - started < 5


def config() -> Any:
    return MODULE.ReviewConfig(
        deployed_revision="1" * 40,
        source_repository="https://github.com/tzehon/wardrobe-stylist",
        fly_app=APP,
        fly_release_version=10,
        region="sin",
        archive_basename="Wardrobe.xcarchive",
        marketing_version="1.0.0",
        build_number="7",
        app_cdhash=APP_CDHASH,
        dsym_uuid=DSYM_UUID,
        backend_url=f"https://{APP}.fly.dev",
        auth_schema_version=4,
        app_attest_app_id_prefix="PREFIXCANARY",
        app_attest_bundle_id="com.example.Wardrobe",
        validation_categories=("2",),
        bundle_versions=("4", "5", "6", "7"),
        required_secret_names=frozenset(
            {"ANTHROPIC_API_KEY", "APP_ATTEST_SESSION_SECRET"}
        ),
        expected_routes=frozenset(
            {
                "/auth/app-attest/challenge",
                "/auth/app-attest/delete",
                "/auth/app-attest/register",
                "/auth/app-attest/session",
                "/health",
                "/recommend",
            }
        ),
        terms_url="https://blog.tth.dev/wardrobe/terms/",
        anthropic_status_url=(
            "https://status.anthropic.com/api/v2/status.json"
        ),
        manual_evidence_max_age=timedelta(minutes=30),
    )


def reviewed_env() -> dict[str, str]:
    return {
        "ENVIRONMENT": "production",
        "AUTH_MODE": "app_attest",
        "APP_ATTEST_ENVIRONMENT": "production",
        "APP_ATTEST_DATABASE_PATH": "/data/app-attest/auth.sqlite3",
        "APP_ATTEST_APP_ID_PREFIX": "PREFIXCANARY",
        "APP_ATTEST_BUNDLE_ID": "com.example.Wardrobe",
        "APP_ATTEST_ALLOWED_VALIDATION_CATEGORIES": "2",
        "APP_ATTEST_ALLOWED_BUNDLE_VERSIONS": "4,5,6,7",
    }


def health_check() -> dict[str, object]:
    return {
        "interval": "30s",
        "timeout": "5s",
        "grace_period": "10s",
        "method": "GET",
        "path": "/health",
    }


def machine_config() -> dict[str, Any]:
    return {
        "image": IMAGE_REF,
        "env": reviewed_env()
        | {"FLY_PROCESS_GROUP": "app", "PRIMARY_REGION": "sin"},
        "services": [
            {
                "protocol": "tcp",
                "internal_port": 8080,
                "autostop": True,
                "autostart": True,
                "min_machines_running": 1,
                "ports": [
                    {"port": 80, "handlers": ["http"], "force_https": True},
                    {"port": 443, "handlers": ["http", "tls"]},
                ],
                "checks": [{"type": "http"} | health_check()],
                "force_instance_key": None,
            }
        ],
        "guest": {"cpu_kind": "shared", "cpus": 1, "memory_mb": 512},
        "restart": {"policy": "on-failure", "max_retries": 10},
        "auto_destroy": None,
        "init": {},
        "mounts": [
            {
                "volume": VOLUME,
                "path": "/data",
                "encrypted": True,
                "size_gb": 1,
                "name": "wardrobe_auth_data",
            }
        ],
    }


def runtime_responses() -> dict[tuple[str, ...], Any]:
    return {
        ("flyctl", "releases", "--json", "--app", APP): output(
            [
                {
                    "Version": 10,
                    "Status": "complete",
                    "InProgress": False,
                    "ImageRef": IMAGE_REF,
                }
            ]
        ),
        ("flyctl", "machine", "list", "--json", "--app", APP): output(
            [
                {
                    "id": MACHINE,
                    "region": "sin",
                    "state": "started",
                    "host_status": "ok",
                    "image_ref": IMAGE_REF,
                    "checks": [{"status": "passing"}],
                    "config": machine_config(),
                }
            ]
        ),
        ("flyctl", "image", "show", "--json", "--app", APP): output(
            [
                {
                    "Digest": DIGEST,
                    "Labels": json.dumps(
                        {
                            "org.opencontainers.image.revision": "1" * 40,
                            "org.opencontainers.image.source": (
                                "https://github.com/tzehon/wardrobe-stylist"
                            ),
                        }
                    ),
                }
            ]
        ),
        ("flyctl", "checks", "list", "--json", "--app", APP): output(
            {SECRET_CANARY: [{"status": "passing"}]}
        ),
    }


def valid_runtime() -> tuple[Any, FakeRunner]:
    runner = FakeRunner(runtime_responses())
    result, runtime = MODULE.collect_runtime(runner, app=APP, config=config())
    assert result.status is MODULE.Status.PASS
    assert runtime is not None
    return runtime, runner


def local_fly() -> dict[str, Any]:
    return {
        "build": {},
        "env": reviewed_env(),
        "primary_region": "sin",
        "mounts": {"source": "wardrobe_auth_data", "destination": "/data"},
        "http_service": {
            "internal_port": 8080,
            "force_https": True,
            "auto_stop_machines": "stop",
            "auto_start_machines": True,
            "min_machines_running": 1,
            "checks": [health_check()],
        },
        "vm": [{"size": "shared-cpu-1x", "memory": "512mb"}],
    }


def live_config() -> dict[str, Any]:
    return {
        "build": None,
        "env": reviewed_env(),
        "primary_region": "sin",
        "mounts": [
            {"source": "wardrobe_auth_data", "destination": "/data"}
        ],
        "http_service": {
            "internal_port": 8080,
            "force_https": True,
            "auto_stop_machines": True,
            "auto_start_machines": True,
            "min_machines_running": 1,
            "checks": [health_check()],
        },
        "vm": [{"size": "shared-cpu-1x", "memory": "512mb"}],
    }


def diagnostics(**overrides: object) -> dict[str, object]:
    values: dict[str, object] = {
        "diagnostic_version": 1,
        "query_only": 1,
        "foreign_keys": 1,
        "secure_delete": 1,
        "synchronous": 2,
        "journal_mode": "wal",
        "schema_version": 4,
        "integrity_ok": True,
        "foreign_key_errors": 0,
        "expected_tables": True,
        "expected_indexes": True,
        "exact_schema": True,
        "unexpected_objects": 0,
        "database_security": True,
        "process_runtime": True,
        "active_installations": 1,
        "active_sessions": 0,
        "pending_challenges": 0,
        "failed_challenges": 0,
        "rate_windows": 4,
        "used_percent": 12.5,
    }
    values.update(overrides)
    return values


def diagnostic_runner(value: dict[str, object]) -> FakeRunner:
    def response() -> Any:
        return MODULE.CommandOutput(
            returncode=0,
            stdout="provider preface\n" + json.dumps(value) + "\n",
        )

    runner = FakeRunner()
    runtime, _ = valid_runtime()
    encoded = MODULE.base64.b64encode(
        MODULE._REMOTE_DIAGNOSTIC.encode("utf-8")
    ).decode("ascii")
    command = (
        "/app/.venv/bin/python -c \"import base64;"
        f"exec(base64.b64decode('{encoded}'))\""
    )
    runner.responses[
        (
            "flyctl",
            "ssh",
            "console",
            "--app",
            APP,
            "--machine",
            runtime.machine_id,
            "--quiet",
            "--command",
            command,
        )
    ] = response
    return runner


def response(url: str, status: int, body: object) -> Any:
    encoded = body if isinstance(body, bytes) else json.dumps(body).encode()
    return MODULE.HTTPResponse(status=status, final_url=url, body=encoded)


def page_response(url: str, body: str) -> Any:
    return MODULE.HTTPResponse(
        status=200,
        final_url=url,
        body=body.encode("utf-8"),
    )


def source_responses(remote_revision: str) -> dict[tuple[str, ...], Any]:
    head = "2" * 40
    runtime_diff = (
        "git",
        "diff",
        "--quiet",
        f"{'1' * 40}..HEAD",
        "--",
        *MODULE.RUNTIME_INPUT_PATHS,
    )
    return {
        ("git", "status", "--porcelain"): "",
        ("git", "rev-parse", "--abbrev-ref", "HEAD"): "main",
        ("git", "rev-parse", "HEAD"): head,
        ("git", "rev-parse", "refs/remotes/origin/main"): head,
        (
            "git",
            "ls-remote",
            "--exit-code",
            config().source_repository,
            "refs/heads/main",
        ): f"{remote_revision}\trefs/heads/main\n",
        (
            "git",
            "merge-base",
            "--is-ancestor",
            "1" * 40,
            "HEAD",
        ): "",
        runtime_diff: "",
        ("git", "remote", "get-url", "origin"): (
            "https://github.com/tzehon/wardrobe-stylist.git\n"
        ),
    }


def test_source_requires_current_remote_main_not_only_tracking_ref() -> None:
    head = "2" * 40
    passing_runner = FakeRunner(source_responses(head))
    passing, passing_revision = MODULE.check_source(
        passing_runner,
        repo_root=Path.cwd(),
        config=config(),
    )
    stale, stale_revision = MODULE.check_source(
        FakeRunner(source_responses("3" * 40)),
        repo_root=Path.cwd(),
        config=config(),
    )

    assert passing.status is MODULE.Status.PASS
    assert passing_revision == head
    assert (
        "git",
        "ls-remote",
        "--exit-code",
        config().source_repository,
        "refs/heads/main",
    ) in passing_runner.calls
    assert (
        "git",
        "ls-remote",
        "--exit-code",
        "origin",
        "refs/heads/main",
    ) not in passing_runner.calls
    assert stale == MODULE._open("source", "local-source-open")
    assert stale_revision is None


def test_archive_identity_requires_pinned_cdhash_and_uuid() -> None:
    uuid_output = MODULE.CommandOutput(
        returncode=0,
        stdout=f"UUID: {DSYM_UUID.upper()} (arm64) Wardrobe\n",
    )
    exact = MODULE._archive_identity_matches(
        code_detail=MODULE.CommandOutput(
            returncode=0, stderr=f"CDHash={APP_CDHASH}\n"
        ),
        app_uuid=uuid_output,
        dsym_uuid=uuid_output,
        config=config(),
    )
    replacement = MODULE._archive_identity_matches(
        code_detail=MODULE.CommandOutput(
            returncode=0, stderr=f"CDHash={'d' * 40}\n"
        ),
        app_uuid=uuid_output,
        dsym_uuid=uuid_output,
        config=config(),
    )

    assert exact is True
    assert replacement is False


def test_archive_backend_must_match_the_locked_fly_deployment() -> None:
    common = {
        "privacy_url": "https://blog.example.com/privacy/",
        "support_url": "https://blog.example.com/support/",
        "config": config(),
    }

    assert MODULE._archive_urls_match_policy(
        backend_url=f"https://{APP}.fly.dev", **common
    )
    assert not MODULE._archive_urls_match_policy(
        backend_url="https://other.example.com", **common
    )


def test_locked_fly_app_must_own_the_archive_backend_hostname() -> None:
    assert MODULE._fly_binding_matches(app=APP, config=config())
    assert not MODULE._fly_binding_matches(app="other-app", config=config())


@pytest.mark.parametrize(
    "host",
    ["127.0.0.1", "10.0.0.1", "192.168.1.1", "169.254.169.254", "[::1]"],
)
def test_public_https_rejects_non_global_ip_literals(host: str) -> None:
    assert not MODULE._is_public_https_url(f"https://{host}/")


def test_runtime_accepts_exact_release_machine_image_and_source() -> None:
    runtime, runner = valid_runtime()

    assert runtime.image_ref == IMAGE_REF
    assert all(SECRET_CANARY not in " ".join(call) for call in runner.calls)


def test_runtime_fails_closed_on_source_or_machine_drift() -> None:
    for mutation in ("revision", "machine"):
        responses = runtime_responses()
        if mutation == "revision":
            responses[
                ("flyctl", "image", "show", "--json", "--app", APP)
            ] = output(
                [
                    {
                        "Digest": DIGEST,
                        "Labels": json.dumps(
                            {
                                "org.opencontainers.image.revision": "2" * 40,
                                "org.opencontainers.image.source": (
                                    "https://github.com/tzehon/wardrobe-stylist"
                                ),
                            }
                        ),
                    }
                ]
            )
        else:
            responses[
                ("flyctl", "machine", "list", "--json", "--app", APP)
            ] = output([])
        result, context = MODULE.collect_runtime(
            FakeRunner(responses), app=APP, config=config()
        )
        assert result == MODULE._open(
            "fly_runtime", "runtime-evidence-open"
        )
        assert context is None


def test_runtime_rejects_malformed_provider_check_payload() -> None:
    responses = runtime_responses()
    responses[("flyctl", "checks", "list", "--json", "--app", APP)] = output(
        {"error": "permission denied"}
    )

    result, context = MODULE.collect_runtime(
        FakeRunner(responses), app=APP, config=config()
    )

    assert result.status is MODULE.Status.OPEN
    assert context is None


def test_runtime_rejects_noncanonical_release_version() -> None:
    responses = runtime_responses()
    releases = [
        {
            "Version": 10.9,
            "Status": "complete",
            "InProgress": False,
            "ImageRef": IMAGE_REF,
        }
    ]
    responses[("flyctl", "releases", "--json", "--app", APP)] = output(
        releases
    )

    result, context = MODULE.collect_runtime(
        FakeRunner(responses), app=APP, config=config()
    )

    assert result.status is MODULE.Status.OPEN
    assert context is None


def test_configuration_accepts_only_deployed_expected_secrets() -> None:
    runtime, _ = valid_runtime()
    runner = FakeRunner(
        {
            ("flyctl", "config", "show", "--app", APP): output(live_config()),
            ("flyctl", "secrets", "list", "--json", "--app", APP): output(
                [
                    {"name": "ANTHROPIC_API_KEY", "status": "Deployed"},
                    {
                        "name": "APP_ATTEST_SESSION_SECRET",
                        "status": "Deployed",
                    },
                ]
            ),
        }
    )

    result = MODULE.check_configuration(
        runner,
        app=APP,
        local_fly=local_fly(),
        runtime=runtime,
        config=config(),
    )

    assert result.status is MODULE.Status.PASS


@pytest.mark.parametrize("status", ["Staged", "Partial", "Unknown"])
def test_configuration_rejects_non_deployed_secret(status: str) -> None:
    runtime, _ = valid_runtime()
    runner = FakeRunner(
        {
            ("flyctl", "config", "show", "--app", APP): output(live_config()),
            ("flyctl", "secrets", "list", "--json", "--app", APP): output(
                [
                    {"name": "ANTHROPIC_API_KEY", "status": status},
                    {
                        "name": "APP_ATTEST_SESSION_SECRET",
                        "status": "Deployed",
                    },
                ]
            ),
        }
    )

    result = MODULE.check_configuration(
        runner,
        app=APP,
        local_fly=local_fly(),
        runtime=runtime,
        config=config(),
    )

    assert result.status is MODULE.Status.OPEN


def test_configuration_rejects_duplicate_secret_with_mixed_status() -> None:
    runtime, _ = valid_runtime()
    runner = FakeRunner(
        {
            ("flyctl", "config", "show", "--app", APP): output(live_config()),
            ("flyctl", "secrets", "list", "--json", "--app", APP): output(
                [
                    {"name": "ANTHROPIC_API_KEY", "status": "Partial"},
                    {"name": "ANTHROPIC_API_KEY", "status": "Deployed"},
                    {
                        "name": "APP_ATTEST_SESSION_SECRET",
                        "status": "Deployed",
                    },
                ]
            ),
        }
    )

    result = MODULE.check_configuration(
        runner,
        app=APP,
        local_fly=local_fly(),
        runtime=runtime,
        config=config(),
    )

    assert result.status is MODULE.Status.OPEN


@pytest.mark.parametrize(
    "field",
    ["APP_ATTEST_APP_ID_PREFIX", "APP_ATTEST_BUNDLE_ID"],
)
def test_configuration_rejects_app_attest_identity_drift(field: str) -> None:
    runtime, _ = valid_runtime()
    drifted = live_config()
    drifted["env"][field] = "wrong"
    runner = FakeRunner(
        {
            ("flyctl", "config", "show", "--app", APP): output(drifted),
            ("flyctl", "secrets", "list", "--json", "--app", APP): output(
                [
                    {"name": "ANTHROPIC_API_KEY", "status": "Deployed"},
                    {
                        "name": "APP_ATTEST_SESSION_SECRET",
                        "status": "Deployed",
                    },
                ]
            ),
        }
    )

    result = MODULE.check_configuration(
        runner,
        app=APP,
        local_fly=local_fly(),
        runtime=runtime,
        config=config(),
    )

    assert result.status is MODULE.Status.OPEN


def test_configuration_rejects_unreviewed_environment_override() -> None:
    runtime, _ = valid_runtime()
    drifted = live_config()
    drifted["env"]["APP_SESSION_TTL_SECONDS"] = "86400"
    runner = FakeRunner(
        {
            ("flyctl", "config", "show", "--app", APP): output(drifted),
            ("flyctl", "secrets", "list", "--json", "--app", APP): output(
                [
                    {"name": "ANTHROPIC_API_KEY", "status": "Deployed"},
                    {
                        "name": "APP_ATTEST_SESSION_SECRET",
                        "status": "Deployed",
                    },
                ]
            ),
        }
    )

    result = MODULE.check_configuration(
        runner,
        app=APP,
        local_fly=local_fly(),
        runtime=runtime,
        config=config(),
    )

    assert result.status is MODULE.Status.OPEN


@pytest.mark.parametrize("drift", ["local-health", "live-vm", "machine-port"])
def test_configuration_rejects_service_or_vm_drift(drift: str) -> None:
    runtime, _ = valid_runtime()
    local = local_fly()
    live = live_config()
    if drift == "local-health":
        local["http_service"]["checks"][0]["path"] = "/other"
    elif drift == "live-vm":
        live["vm"][0]["memory"] = "1024mb"
    else:
        runtime.machine_config["services"][0]["ports"].append(
            {"port": 9000, "handlers": ["http"]}
        )
    runner = FakeRunner(
        {
            ("flyctl", "config", "show", "--app", APP): output(live),
            ("flyctl", "secrets", "list", "--json", "--app", APP): output(
                [
                    {"name": "ANTHROPIC_API_KEY", "status": "Deployed"},
                    {
                        "name": "APP_ATTEST_SESSION_SECRET",
                        "status": "Deployed",
                    },
                ]
            ),
        }
    )

    result = MODULE.check_configuration(
        runner,
        app=APP,
        local_fly=local,
        runtime=runtime,
        config=config(),
    )

    assert result.status is MODULE.Status.OPEN


@pytest.mark.parametrize(
    "services",
    ["schema-drift", 7, False, {}, {"ports": []}, [{"ports": []}]],
)
def test_configuration_rejects_malformed_or_extra_live_services(
    services: object,
) -> None:
    runtime, _ = valid_runtime()
    live = live_config()
    live["services"] = services
    runner = FakeRunner(
        {
            ("flyctl", "config", "show", "--app", APP): output(live),
            ("flyctl", "secrets", "list", "--json", "--app", APP): output(
                [
                    {"name": "ANTHROPIC_API_KEY", "status": "Deployed"},
                    {
                        "name": "APP_ATTEST_SESSION_SECRET",
                        "status": "Deployed",
                    },
                ]
            ),
        }
    )

    result = MODULE.check_configuration(
        runner,
        app=APP,
        local_fly=local_fly(),
        runtime=runtime,
        config=config(),
    )

    assert result.status is MODULE.Status.OPEN


def test_snapshot_exactly_36_hours_old_passes_and_retains_only_safe_fields() -> None:
    runtime, _ = valid_runtime()
    runner = FakeRunner(
        {
            ("flyctl", "volumes", "list", "--json", "--app", APP): output(
                [
                    {
                        "id": VOLUME,
                        "encrypted": True,
                        "state": "created",
                        "region": "sin",
                        "auto_backup_enabled": True,
                        "snapshot_retention": 14,
                        "attached_machine_id": MACHINE,
                    }
                ]
            ),
            (
                "flyctl",
                "volumes",
                "snapshots",
                "list",
                VOLUME,
                "--json",
                "--app",
                APP,
            ): output(
                [
                    {
                        "id": SECRET_CANARY,
                        "created_at": MODULE._format_utc(
                            NOW - timedelta(hours=36)
                        ),
                        "status": "created",
                        "retention_days": 14,
                    }
                ]
            ),
        }
    )

    result, storage = MODULE.collect_storage(
        runner,
        app=APP,
        runtime=runtime,
        config=config(),
        now=NOW,
    )

    assert result.status is MODULE.Status.PASS
    assert storage is not None
    report = MODULE.ReviewReport(
        checked_at=NOW,
        results=tuple(
            MODULE._pass(name, MODULE._PASS_DETAILS[name])
            for name in MODULE.CHECK_ORDER
        ),
        snapshot=storage.snapshot,
    ).render()
    assert SECRET_CANARY not in report
    assert VOLUME not in report
    assert "snapshot_newest_utc=" in report


def test_snapshot_rejects_machine_mount_drift() -> None:
    runtime, _ = valid_runtime()
    runtime.machine_config["mounts"][0]["path"] = "/other"
    runner = FakeRunner(
        {
            ("flyctl", "volumes", "list", "--json", "--app", APP): output(
                [
                    {
                        "id": VOLUME,
                        "encrypted": True,
                        "state": "created",
                        "region": "sin",
                        "auto_backup_enabled": True,
                        "snapshot_retention": 14,
                        "attached_machine_id": MACHINE,
                    }
                ]
            )
        }
    )

    result, storage = MODULE.collect_storage(
        runner,
        app=APP,
        runtime=runtime,
        config=config(),
        now=NOW,
    )

    assert result.status is MODULE.Status.OPEN
    assert storage is None


@pytest.mark.parametrize(
    ("age", "retention", "status"),
    [
        (timedelta(hours=36, seconds=1), 14, "created"),
        (timedelta(hours=1), 30, "created"),
        (timedelta(hours=1), 14, "failed"),
        (timedelta(seconds=-1), 14, "created"),
    ],
)
def test_snapshot_stale_failed_unknown_or_future_is_open(
    age: timedelta, retention: int, status: str
) -> None:
    runtime, _ = valid_runtime()
    runner = FakeRunner(
        {
            ("flyctl", "volumes", "list", "--json", "--app", APP): output(
                [
                    {
                        "id": VOLUME,
                        "encrypted": True,
                        "state": "created",
                        "region": "sin",
                        "auto_backup_enabled": True,
                        "snapshot_retention": 14,
                        "attached_machine_id": MACHINE,
                    }
                ]
            ),
            (
                "flyctl",
                "volumes",
                "snapshots",
                "list",
                VOLUME,
                "--json",
                "--app",
                APP,
            ): output(
                [
                    {
                        "created_at": MODULE._format_utc(NOW - age),
                        "status": status,
                        "retention_days": retention,
                    }
                ]
            ),
        }
    )

    result, storage = MODULE.collect_storage(
        runner,
        app=APP,
        runtime=runtime,
        config=config(),
        now=NOW,
    )

    assert result.status is MODULE.Status.OPEN
    assert storage is None


@pytest.mark.parametrize(
    ("usage", "expected_status"),
    [
        (69.999, MODULE.Status.PASS),
        (70.0, MODULE.Status.WARNING),
        (84.999, MODULE.Status.WARNING),
        (85.0, MODULE.Status.OPEN),
    ],
)
def test_volume_policy_boundaries(usage: float, expected_status: Any) -> None:
    runtime, _ = valid_runtime()
    runner = diagnostic_runner(diagnostics(used_percent=usage))

    auth_store, aggregate, volume = MODULE.collect_diagnostics(
        runner, runtime=runtime, config=config()
    )

    assert auth_store.status is MODULE.Status.PASS
    assert aggregate.status is MODULE.Status.PASS
    assert volume.status is expected_status


@pytest.mark.parametrize(
    ("overrides", "open_check"),
    [
        ({"schema_version": 5}, "auth_store"),
        ({"exact_schema": False}, "auth_store"),
        ({"integrity_ok": False}, "auth_store"),
        ({"foreign_key_errors": 1}, "auth_store"),
        ({"process_runtime": False}, "auth_store"),
        ({"active_installations": 2}, "auth_aggregate"),
        ({"pending_challenges": 1}, "auth_aggregate"),
        ({"failed_challenges": 1}, "auth_aggregate"),
    ],
)
def test_diagnostics_fail_closed_on_store_or_aggregate_drift(
    overrides: dict[str, object], open_check: str
) -> None:
    runtime, _ = valid_runtime()
    runner = diagnostic_runner(diagnostics(**overrides))

    results = MODULE.collect_diagnostics(
        runner, runtime=runtime, config=config()
    )
    by_name = {result.name: result for result in results}

    assert by_name[open_check].status is MODULE.Status.OPEN


def test_diagnostics_rejects_session_without_active_installation() -> None:
    runtime, _ = valid_runtime()
    runner = diagnostic_runner(
        diagnostics(active_installations=0, active_sessions=1)
    )

    _, aggregate, _ = MODULE.collect_diagnostics(
        runner, runtime=runtime, config=config()
    )

    assert aggregate.status is MODULE.Status.OPEN


@pytest.mark.parametrize(
    ("auth_count", "service_count", "expected"),
    [
        (4, 2, MODULE.Status.PASS),
        (5, 0, MODULE.Status.OPEN),
        (0, 3, MODULE.Status.OPEN),
    ],
)
def test_bounded_event_thresholds(
    auth_count: int, service_count: int, expected: Any
) -> None:
    rows = [
        {
            "timestamp": MODULE._format_utc(NOW - timedelta(minutes=1)),
            "message": "auth_security_event event=rate_limit_exceeded",
        }
        for _ in range(auth_count)
    ] + [
        {
            "timestamp": MODULE._format_utc(NOW - timedelta(minutes=1)),
            "message": "anthropic_request_failed " + SECRET_CANARY,
        }
        for _ in range(service_count)
    ]
    runner = FakeRunner(
        {
            ("flyctl", "logs", "--no-tail", "--json", "--app", APP): (
                MODULE.CommandOutput(
                    returncode=0,
                    stdout="\n".join(json.dumps(row) for row in rows),
                )
            )
        }
    )

    result = MODULE.check_bounded_events(runner, app=APP, now=NOW)

    assert result.status is expected
    assert SECRET_CANARY not in result.detail


def test_empty_log_buffer_is_open_and_never_substitutes_for_official_metric() -> None:
    runner = FakeRunner(
        {
            ("flyctl", "logs", "--no-tail", "--json", "--app", APP): (
                MODULE.CommandOutput(returncode=0, stdout="")
            )
        }
    )

    events = MODULE.check_bounded_events(runner, app=APP, now=NOW)
    manual = MODULE.manual_results(
        evidence_path=None, config=config(), now=NOW
    )

    assert events.status is MODULE.Status.OPEN
    assert manual[0] == MODULE._open(
        "official_fly_metrics", "manual-review-required"
    )


def test_log_buffer_rejects_non_json_provider_output() -> None:
    runner = FakeRunner(
        {
            ("flyctl", "logs", "--no-tail", "--json", "--app", APP): (
                MODULE.CommandOutput(returncode=0, stdout="permission denied\n")
            )
        }
    )

    result = MODULE.check_bounded_events(runner, app=APP, now=NOW)

    assert result == MODULE._open("bounded_events", "event-evidence-open")


def test_log_buffer_rejects_json_schema_drift() -> None:
    runner = FakeRunner(
        {
            ("flyctl", "logs", "--no-tail", "--json", "--app", APP): (
                MODULE.CommandOutput(
                    returncode=0,
                    stdout=json.dumps({"error": "permission denied"}) + "\n",
                )
            )
        }
    )

    result = MODULE.check_bounded_events(runner, app=APP, now=NOW)

    assert result == MODULE._open("bounded_events", "event-evidence-open")


def test_log_buffer_rejects_recognized_event_after_review_start() -> None:
    row = {
        "timestamp": MODULE._format_utc(NOW + timedelta(seconds=1)),
        "message": "auth_security_event event=rate_limit_exceeded",
    }
    runner = FakeRunner(
        {
            ("flyctl", "logs", "--no-tail", "--json", "--app", APP): (
                MODULE.CommandOutput(returncode=0, stdout=json.dumps(row) + "\n")
            )
        }
    )

    result = MODULE.check_bounded_events(runner, app=APP, now=NOW)

    assert result == MODULE._open("bounded_events", "event-evidence-open")


def test_log_buffer_requires_current_timestamped_coverage() -> None:
    stale = {
        "timestamp": MODULE._format_utc(NOW - timedelta(minutes=11)),
        "message": "platform instance started",
    }
    current = {
        "timestamp": MODULE._format_utc(NOW - timedelta(minutes=1)),
        "message": "platform instance healthy",
    }

    stale_result = MODULE.check_bounded_events(
        FakeRunner(
            {
                ("flyctl", "logs", "--no-tail", "--json", "--app", APP): (
                    MODULE.CommandOutput(
                        returncode=0, stdout=json.dumps(stale) + "\n"
                    )
                )
            }
        ),
        app=APP,
        now=NOW,
    )
    current_result = MODULE.check_bounded_events(
        FakeRunner(
            {
                ("flyctl", "logs", "--no-tail", "--json", "--app", APP): (
                    MODULE.CommandOutput(
                        returncode=0, stdout=json.dumps(current) + "\n"
                    )
                )
            }
        ),
        app=APP,
        now=NOW,
    )

    assert stale_result.status is MODULE.Status.OPEN
    assert current_result.status is MODULE.Status.PASS


def test_log_buffer_accepts_concatenated_pretty_json_objects() -> None:
    rows = (
        {
            "timestamp": MODULE._format_utc(NOW - timedelta(minutes=2)),
            "message": "platform instance started",
        },
        {
            "timestamp": MODULE._format_utc(NOW - timedelta(minutes=1)),
            "message": "platform instance healthy",
        },
    )
    pretty_stream = "\n".join(json.dumps(row, indent=2) for row in rows)
    runner = FakeRunner(
        {
            ("flyctl", "logs", "--no-tail", "--json", "--app", APP): (
                MODULE.CommandOutput(returncode=0, stdout=pretty_stream)
            )
        }
    )

    result = MODULE.check_bounded_events(runner, app=APP, now=NOW)

    assert result.status is MODULE.Status.PASS


def test_public_backend_checks_health_exact_routes_and_retired_route() -> None:
    archive = MODULE.ArchiveContext(
        backend_url="https://api.example.com",
        privacy_url="https://blog.example.com/privacy/",
        support_url="https://blog.example.com/support/",
    )
    openapi = {"paths": {route: {} for route in config().expected_routes}}
    getter = FakeGetter(
        {
            "https://api.example.com/health": response(
                "https://api.example.com/health",
                200,
                {"status": "ok", "environment": "production"},
            ),
            "https://api.example.com/openapi.json": response(
                "https://api.example.com/openapi.json", 200, openapi
            ),
            "https://api.example.com/extract": response(
                "https://api.example.com/extract", 404, {"detail": "not found"}
            ),
        }
    )

    result = MODULE.check_public_backend(
        getter, archive=archive, config=config()
    )

    assert result.status is MODULE.Status.PASS
    assert all(call.endswith(("/health", "/openapi.json", "/extract")) for call in getter.calls)
    assert not any(call.endswith("/recommend") for call in getter.calls)


def test_public_pages_require_content_contact_and_reciprocal_links() -> None:
    support = "https://blog.tth.dev/wardrobe/support/"
    privacy = "https://blog.tth.dev/wardrobe/privacy/"
    terms = "https://blog.tth.dev/wardrobe/terms/"
    archive = MODULE.ArchiveContext(
        backend_url="https://api.example.com",
        privacy_url=privacy,
        support_url=support,
    )
    nav = (
        f'<a href="{support}">Support</a>'
        f'<a href="{privacy}">Privacy</a>'
        f'<a href="{terms}">Terms</a>'
        '<a href="mailto:contact@tth.dev">Contact</a>'
    )
    getter = FakeGetter(
        {
            support: page_response(
                support,
                "Wardrobe Stylist delete server security data two business days "
                + nav,
            ),
            privacy: page_response(
                privacy,
                "Wardrobe Stylist App Attest Anthropic Fly.io rolling 14-day snapshots "
                + nav,
            ),
            terms: page_response(terms, "Wardrobe Stylist Terms " + nav),
        }
    )

    result = MODULE.check_public_pages(
        getter, archive=archive, config=config()
    )

    assert result.status is MODULE.Status.PASS


def test_manual_evidence_is_fresh_fixed_field_and_never_upload_approval() -> None:
    body = "\n".join(
        (
            f'checked_at_utc = "{MODULE._format_utc(NOW - timedelta(minutes=30))}"',
            f'marketing_version = "{config().marketing_version}"',
            f'build_number = "{config().build_number}"',
            f'archive_cdhash = "{config().app_cdhash}"',
            f'deployed_revision = "{config().deployed_revision}"',
            'official_fly_metrics = "pass"',
            'anthropic_console = "pass"',
            'app_store_connect = "pass"',
        )
    )
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "manual.toml"
        path.write_text(body, encoding="utf-8")

        results = MODULE.manual_results(
            evidence_path=path, config=config(), now=NOW
        )

    assert all(result.status is MODULE.Status.PASS for result in results)
    report_results = tuple(
        MODULE._pass(name, MODULE._PASS_DETAILS[name])
        for name in MODULE.CHECK_ORDER
    )
    rendered = MODULE.ReviewReport(
        checked_at=NOW, results=report_results
    ).render()
    assert "owner-upload-approval-still-required" in rendered


def test_stale_future_or_extra_manual_evidence_is_open() -> None:
    fixtures = (
        {
            "checked_at_utc": MODULE._format_utc(NOW - timedelta(minutes=31)),
            "marketing_version": config().marketing_version,
            "build_number": config().build_number,
            "archive_cdhash": config().app_cdhash,
            "deployed_revision": config().deployed_revision,
            "official_fly_metrics": "pass",
            "anthropic_console": "pass",
            "app_store_connect": "pass",
        },
        {
            "checked_at_utc": MODULE._format_utc(NOW + timedelta(seconds=1)),
            "marketing_version": config().marketing_version,
            "build_number": config().build_number,
            "archive_cdhash": config().app_cdhash,
            "deployed_revision": config().deployed_revision,
            "official_fly_metrics": "pass",
            "anthropic_console": "pass",
            "app_store_connect": "pass",
        },
        {
            "checked_at_utc": MODULE._format_utc(NOW),
            "marketing_version": config().marketing_version,
            "build_number": config().build_number,
            "archive_cdhash": config().app_cdhash,
            "deployed_revision": config().deployed_revision,
            "official_fly_metrics": "pass",
            "anthropic_console": "pass",
            "app_store_connect": "pass",
            "owner_upload_approval": "pass",
        },
        {
            "checked_at_utc": MODULE._format_utc(NOW),
            "marketing_version": config().marketing_version,
            "build_number": "8",
            "archive_cdhash": config().app_cdhash,
            "deployed_revision": config().deployed_revision,
            "official_fly_metrics": "pass",
            "anthropic_console": "pass",
            "app_store_connect": "pass",
        },
    )
    for fixture in fixtures:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manual.toml"
            path.write_text(
                "\n".join(f'{key} = "{value}"' for key, value in fixture.items()),
                encoding="utf-8",
            )
            results = MODULE.manual_results(
                evidence_path=path, config=config(), now=NOW
            )
        assert all(result.status is MODULE.Status.OPEN for result in results)


def test_run_review_rechecks_source_and_manual_evidence_at_completion(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    review_config = config()
    evidence = tmp_path / "manual.toml"
    evidence.write_text(
        "\n".join(
            (
                f'checked_at_utc = "{MODULE._format_utc(NOW)}"',
                f'marketing_version = "{review_config.marketing_version}"',
                f'build_number = "{review_config.build_number}"',
                f'archive_cdhash = "{review_config.app_cdhash}"',
                f'deployed_revision = "{review_config.deployed_revision}"',
                'official_fly_metrics = "pass"',
                'anthropic_console = "pass"',
                'app_store_connect = "pass"',
            )
        ),
        encoding="utf-8",
    )
    archive = MODULE.ArchiveContext(
        backend_url=review_config.backend_url,
        privacy_url="https://blog.example.com/privacy/",
        support_url="https://blog.example.com/support/",
    )
    runtime = MODULE.RuntimeContext(
        app=APP,
        machine_id=MACHINE,
        image_ref=IMAGE_REF,
        machine_config=machine_config(),
    )
    snapshot = MODULE.SnapshotMetadata(
        created_at=NOW - timedelta(hours=1),
        status="created",
        retention_days=14,
    )
    monkeypatch.setattr(
        MODULE.ReviewConfig,
        "load",
        classmethod(lambda _cls, _path: review_config),
    )
    monkeypatch.setattr(MODULE, "_load_local_fly", lambda _path: ({}, APP))
    source_results = iter(
        (
            (MODULE._pass("source", "clean-synchronized"), "a" * 40),
            (MODULE._pass("source", "clean-synchronized"), "b" * 40),
        )
    )
    monkeypatch.setattr(
        MODULE,
        "check_source",
        lambda *_args, **_kwargs: next(source_results),
    )
    monkeypatch.setattr(
        MODULE,
        "check_archive",
        lambda *_args, **_kwargs: (
            MODULE._pass("archive", "strict-artifact-match"),
            archive,
        ),
    )
    monkeypatch.setattr(
        MODULE,
        "collect_runtime",
        lambda *_args, **_kwargs: (
            MODULE._pass("fly_runtime", "exact-healthy-runtime"),
            runtime,
        ),
    )
    monkeypatch.setattr(
        MODULE,
        "check_configuration",
        lambda *_args, **_kwargs: MODULE._pass(
            "fly_configuration", "app-attest-only"
        ),
    )
    monkeypatch.setattr(
        MODULE,
        "collect_storage",
        lambda *_args, **_kwargs: (
            MODULE._pass("snapshot", "automatic-14-day-fresh"),
            MODULE.StorageContext(volume_id=VOLUME, snapshot=snapshot),
        ),
    )
    monkeypatch.setattr(
        MODULE,
        "collect_diagnostics",
        lambda *_args, **_kwargs: (
            MODULE._pass("auth_store", "schema-integrity-and-runtime-guards"),
            MODULE._pass("auth_aggregate", "single-user-band"),
            MODULE._pass("volume", "below-70-percent"),
        ),
    )
    monkeypatch.setattr(
        MODULE,
        "check_bounded_events",
        lambda *_args, **_kwargs: MODULE._pass(
            "bounded_events", "below-policy-threshold"
        ),
    )
    monkeypatch.setattr(
        MODULE,
        "check_public_backend",
        lambda *_args, **_kwargs: MODULE._pass(
            "public_backend", "health-and-routes"
        ),
    )
    monkeypatch.setattr(
        MODULE,
        "check_public_pages",
        lambda *_args, **_kwargs: MODULE._pass(
            "public_pages", "support-privacy-terms"
        ),
    )
    monkeypatch.setattr(
        MODULE,
        "check_anthropic_status",
        lambda *_args, **_kwargs: MODULE._pass(
            "anthropic_status", "public-status-operational"
        ),
    )
    monkeypatch.setattr(
        MODULE,
        "check_recovery_scan",
        lambda *_args, **_kwargs: MODULE._pass(
            "recovery_scan", "exact-linux-amd64-zero-high-critical"
        ),
    )
    clock_values = iter((NOW, NOW, NOW + timedelta(minutes=31)))

    report = MODULE.run_review(
        repo_root=tmp_path,
        archive_path=tmp_path / "Wardrobe.xcarchive",
        evidence_path=evidence,
        refresh_registry_auth=True,
        runner=FakeRunner(),
        getter=FakeGetter({}),
        clock=lambda: next(clock_values),
    )

    by_name = {result.name: result for result in report.results}
    assert report.checked_at == NOW + timedelta(minutes=31)
    assert by_name["official_fly_metrics"].status is MODULE.Status.OPEN
    assert by_name["anthropic_console"].status is MODULE.Status.OPEN
    assert by_name["app_store_connect"].status is MODULE.Status.OPEN
    assert by_name["source"].status is MODULE.Status.OPEN


def test_recovery_scan_uses_only_read_only_registry_commands() -> None:
    runtime, _ = valid_runtime()
    manifest = {
        "digest": DIGEST,
        "platform": {"os": "linux", "architecture": "amd64"},
    }
    runner = FakeRunner(
        {
            ("flyctl", "auth", "docker"): MODULE.CommandOutput(returncode=0),
            (
                "docker",
                "buildx",
                "imagetools",
                "inspect",
                "--format",
                "{{json .Manifest}}",
                IMAGE_REF,
            ): json.dumps(manifest),
            (
                "docker",
                "buildx",
                "imagetools",
                "inspect",
                "--format",
                "{{json .Image}}",
                IMAGE_REF,
            ): json.dumps({"os": "linux", "architecture": "amd64"}),
            (
                "docker",
                "scout",
                "cves",
                "--only-severity",
                "critical,high",
                "--exit-code",
                "--platform",
                "linux/amd64",
                "registry://" + IMAGE_REF,
            ): MODULE.CommandOutput(returncode=0, stderr=SECRET_CANARY),
        }
    )

    result = MODULE.check_recovery_scan(
        runner, runtime=runtime, refresh_registry_auth=True
    )

    assert result.status is MODULE.Status.PASS
    joined = "\n".join(" ".join(call) for call in runner.calls)
    assert not any(
        verb in joined
        for verb in (" deploy ", " create ", " delete ", " destroy ", " restore ")
    )
    assert SECRET_CANARY not in result.detail


def test_recovery_scan_rejects_malformed_manifest_shape() -> None:
    runtime, _ = valid_runtime()
    runner = FakeRunner(
        {
            ("flyctl", "auth", "docker"): MODULE.CommandOutput(returncode=0),
            (
                "docker",
                "buildx",
                "imagetools",
                "inspect",
                "--format",
                "{{json .Manifest}}",
                IMAGE_REF,
            ): json.dumps([]),
            (
                "docker",
                "buildx",
                "imagetools",
                "inspect",
                "--format",
                "{{json .Image}}",
                IMAGE_REF,
            ): json.dumps(None),
        }
    )

    result = MODULE.check_recovery_scan(
        runner, runtime=runtime, refresh_registry_auth=True
    )

    assert result == MODULE._open("recovery_scan", "recovery-scan-open")


def test_recovery_scan_requires_fresh_ephemeral_registry_auth() -> None:
    runtime, _ = valid_runtime()
    runner = FakeRunner()

    result = MODULE.check_recovery_scan(
        runner, runtime=runtime, refresh_registry_auth=False
    )

    assert result == MODULE._open("recovery_scan", "recovery-scan-open")
    assert runner.calls == []


def test_failure_report_never_renders_raw_provider_canaries() -> None:
    results = tuple(
        MODULE._open(name, _open_detail(name)) for name in MODULE.CHECK_ORDER
    )
    report = MODULE.ReviewReport(checked_at=NOW, results=results)

    rendered = report.render()

    for canary in (SECRET_CANARY, APP, MACHINE, VOLUME, DIGEST, IMAGE_REF):
        assert canary not in rendered
    assert report.passed is False


def test_check_result_rejects_pass_status_with_open_detail() -> None:
    with pytest.raises(MODULE.ReviewConfigurationError):
        MODULE.CheckResult(
            name="source",
            status=MODULE.Status.PASS,
            detail="local-source-open",
        )


def _open_detail(name: str) -> str:
    return {
        "source": "local-source-open",
        "archive": "archive-open",
        "fly_runtime": "runtime-evidence-open",
        "fly_configuration": "configuration-evidence-open",
        "auth_store": "auth-store-evidence-open",
        "auth_aggregate": "auth-aggregate-open",
        "volume": "volume-evidence-open",
        "snapshot": "snapshot-evidence-open",
        "bounded_events": "event-evidence-open",
        "public_backend": "public-backend-open",
        "public_pages": "public-pages-open",
        "anthropic_status": "public-status-open",
        "recovery_scan": "recovery-scan-open",
        "official_fly_metrics": "manual-review-open",
        "anthropic_console": "manual-review-open",
        "app_store_connect": "manual-review-open",
    }[name]
