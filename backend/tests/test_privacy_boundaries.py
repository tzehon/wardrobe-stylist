"""Structural guards for developer-controlled persistence and logging sinks."""

from __future__ import annotations

import ast
import sqlite3
from pathlib import Path

from app.auth.store import AuthStore

BACKEND_ROOT = Path(__file__).resolve().parents[1]
APP_ROOT = BACKEND_ROOT / "app"

# Any auth-schema change must be reviewed here. Exact names avoid both a weak
# substring scan and a false positive for ``receipt``, which is Apple's opaque
# App Attest receipt rather than a Gmail purchase receipt.
EXPECTED_AUTH_SCHEMA = {
    "challenges": (
        "challenge_id",
        "secret",
        "purpose",
        "key_id",
        "expires_at",
        "state",
        "payload_hash",
        "completed_session_id",
        "created_at",
    ),
    "installations": (
        "installation_id",
        "key_id",
        "public_key_der",
        "receipt",
        "app_id",
        "attest_environment",
        "sign_count",
        "validation_category",
        "bundle_version",
        "attested_at",
        "last_seen_at",
        "revoked_at",
    ),
    "sessions": (
        "session_id",
        "installation_id",
        "token_hash",
        "expires_at",
        "created_at",
        "revoked_at",
    ),
    "rate_windows": (
        "scope",
        "subject_hash",
        "window_start",
        "expires_at",
        "request_count",
    ),
}

# This is deliberately a complete allowlist. Adding an application log is a
# privacy-sensitive change and must update this review boundary. The dynamic
# route/auth tests separately inject private sentinels to prove these reviewed
# exception and validation paths remain payload-free at runtime.
EXPECTED_LOG_CALLS = {
    (
        "anthropic_safety.py",
        "warning",
        "'anthropic_concurrency_rejected limit=%d'",
        "MAX_CONCURRENT_ANTHROPIC_REQUESTS",
    ),
    (
        "anthropic_safety.py",
        "warning",
        "'anthropic_request_failed type=%s status=%s request_id=%s'",
        "type(error).__name__",
        "upstream_status if upstream_status is not None else '-'",
        "request_id",
    ),
    (
        "auth/service.py",
        "log",
        "level",
        "'auth_security_event event=%s code=%s scope=%s path=%s mechanism=%s'",
        "event",
        "code",
        "scope",
        "path",
        "mechanism",
    ),
    (
        "http_security.py",
        "error",
        "'unhandled_api_error type=%s'",
        "type(exc).__name__",
    ),
    (
        "routes/extract.py",
        "error",
        "'Receipt snippet preprocessing returned no content.'",
    ),
    (
        "routes/extract.py",
        "warning",
        "'extractor_failure code=invalid_model_response'",
    ),
    (
        "routes/extract.py",
        "warning",
        "'Tool input failed schema validation: count=%d types=%s'",
        "exc.error_count()",
        "validation_types",
    ),
    (
        "routes/recommend.py",
        "warning",
        "'stylist_failure code=invalid_model_response'",
    ),
    (
        "routes/recommend.py",
        "warning",
        "'stylist_failure code=unsalvageable_outfit'",
    ),
    (
        "routes/recommend.py",
        "warning",
        "'Tool input failed schema validation: count=%d types=%s'",
        "exc.error_count()",
        "validation_types",
    ),
}

PERSISTENCE_MODULE_ROOTS = {
    "boto3",
    "dbm",
    "marshal",
    "pickle",
    "pymongo",
    "redis",
    "shelve",
    "sqlalchemy",
    "sqlite3",
    "tempfile",
}
WRITE_METHODS = {
    "write",
    "writelines",
    "write_bytes",
    "write_text",
    "writerow",
    "writerows",
}
COPY_OR_MOVE_METHODS = {"copy", "copy2", "copyfile", "copytree", "move"}
PERSISTENT_LOG_HANDLER_NAMES = {
    "FileHandler",
    "RotatingFileHandler",
    "TimedRotatingFileHandler",
    "WatchedFileHandler",
}
LOG_METHODS = {"critical", "debug", "error", "exception", "info", "log", "warning"}
DIRECT_DIAGNOSTIC_SINKS = {
    "pprint.pprint",
    "traceback.print_exc",
    "traceback.print_exception",
    "warnings.warn",
}
PAYLOAD_MODULES = {
    "agents/extractor.py",
    "agents/stylist.py",
    "routes/extract.py",
    "routes/recommend.py",
    "schemas/purchase.py",
    "schemas/recommendation.py",
}


def _app_sources() -> list[Path]:
    return sorted(APP_ROOT.rglob("*.py"))


def _relative(path: Path) -> str:
    return path.relative_to(APP_ROOT).as_posix()


def _import_aliases(tree: ast.AST) -> dict[str, str]:
    aliases: dict[str, str] = {}
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for imported in node.names:
                local_name = imported.asname or imported.name.split(".", 1)[0]
                aliases[local_name] = imported.name
        elif isinstance(node, ast.ImportFrom) and node.module:
            for imported in node.names:
                local_name = imported.asname or imported.name
                aliases[local_name] = f"{node.module}.{imported.name}"
    return aliases


def _qualified_name(node: ast.AST, aliases: dict[str, str]) -> str | None:
    if isinstance(node, ast.Name):
        return aliases.get(node.id, node.id)
    if isinstance(node, ast.Attribute):
        prefix = _qualified_name(node.value, aliases)
        return f"{prefix}.{node.attr}" if prefix else node.attr
    return None


def _logger_names(tree: ast.AST, aliases: dict[str, str]) -> set[str]:
    names = {"logger"}
    changed = True
    while changed:
        changed = False
        for node in ast.walk(tree):
            if not isinstance(node, (ast.Assign, ast.AnnAssign)):
                continue
            targets = node.targets if isinstance(node, ast.Assign) else [node.target]
            target_names = {
                target.id for target in targets if isinstance(target, ast.Name)
            }
            value = node.value
            is_get_logger = (
                isinstance(value, ast.Call)
                and _qualified_name(value.func, aliases) == "logging.getLogger"
            )
            is_logger_alias = isinstance(value, ast.Name) and value.id in names
            if is_get_logger or is_logger_alias:
                before = len(names)
                names.update(target_names)
                changed = changed or len(names) != before
    return names


def _open_mode(call: ast.Call, *, method_style: bool) -> ast.AST | None:
    positional_index = 0 if method_style else 1
    mode = call.args[positional_index] if len(call.args) > positional_index else None
    return next(
        (keyword.value for keyword in call.keywords if keyword.arg == "mode"),
        mode,
    )


def _is_writable_open(call: ast.Call, *, method_style: bool) -> bool:
    mode = _open_mode(call, method_style=method_style)
    return mode is not None and (
        not isinstance(mode, ast.Constant)
        or not isinstance(mode.value, str)
        or any(flag in mode.value for flag in "wax+")
    )


def _persistence_violations(relative_path: str, source: str) -> list[str]:
    violations: list[str] = []
    tree = ast.parse(source, filename=relative_path)
    aliases = _import_aliases(tree)
    is_store = relative_path == "auth/store.py"

    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for imported in node.names:
                imported_root = imported.name.split(".", 1)[0]
                if imported_root in PERSISTENCE_MODULE_ROOTS and not is_store:
                    violations.append(
                        f"{relative_path}:{node.lineno} imports {imported.name}"
                    )
                if (
                    relative_path in PAYLOAD_MODULES
                    and imported.name == "app.auth.store"
                ):
                    violations.append(
                        f"{relative_path}:{node.lineno} imports the durable auth store"
                    )
            continue

        if isinstance(node, ast.ImportFrom) and node.module:
            imported_root = node.module.split(".", 1)[0]
            if imported_root in PERSISTENCE_MODULE_ROOTS and not is_store:
                violations.append(
                    f"{relative_path}:{node.lineno} imports {node.module}"
                )
            imports_store = node.module == "app.auth.store" or (
                node.module == "app.auth"
                and any(imported.name == "store" for imported in node.names)
            )
            if relative_path in PAYLOAD_MODULES and imports_store:
                violations.append(
                    f"{relative_path}:{node.lineno} imports the durable auth store"
                )
            continue

        if not isinstance(node, ast.Call):
            continue

        qualified_call = _qualified_name(node.func, aliases)
        method_style_open = (
            isinstance(node.func, ast.Attribute)
            and node.func.attr == "open"
            and qualified_call != "os.open"
        )
        if (
            isinstance(node.func, ast.Attribute)
            and node.func.attr in WRITE_METHODS
            and not is_store
        ):
            violations.append(
                f"{relative_path}:{node.lineno} calls .{node.func.attr}()"
            )
        elif (
            qualified_call in {"open", "builtins.open", "io.open"}
            or method_style_open
        ) and _is_writable_open(node, method_style=method_style_open):
            if not is_store:
                violations.append(
                    f"{relative_path}:{node.lineno} opens a writable file"
                )
        elif qualified_call == "os.open" and not is_store:
            violations.append(f"{relative_path}:{node.lineno} calls os.open()")
        elif qualified_call == "json.dump" and not is_store:
            violations.append(f"{relative_path}:{node.lineno} calls json.dump()")
        elif (
            qualified_call is not None
            and qualified_call.rsplit(".", 1)[-1] in COPY_OR_MOVE_METHODS
            and qualified_call.split(".", 1)[0] in {"os", "shutil"}
            and not is_store
        ):
            violations.append(
                f"{relative_path}:{node.lineno} copies or moves durable data"
            )
        elif (
            qualified_call is not None
            and qualified_call.rsplit(".", 1)[-1] in PERSISTENT_LOG_HANDLER_NAMES
        ):
            violations.append(
                f"{relative_path}:{node.lineno} configures a persistent log handler"
            )

    return violations


def test_auth_store_schema_is_exactly_reviewed_security_metadata(tmp_path: Path) -> None:
    database_path = tmp_path / "private-auth" / "auth.sqlite3"
    AuthStore(database_path).initialize()

    with sqlite3.connect(database_path) as connection:
        table_names = {
            str(row[0])
            for row in connection.execute(
                """
                SELECT name FROM sqlite_master
                WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
                """
            )
        }
        actual_schema = {
            table: tuple(
                str(row[1])
                for row in connection.execute(f'PRAGMA table_info("{table}")')
            )
            for table in table_names
        }

    assert actual_schema == EXPECTED_AUTH_SCHEMA


def test_auth_store_remains_the_only_developer_controlled_persistence_sink() -> None:
    violations: list[str] = []
    for path in _app_sources():
        relative_path = _relative(path)
        violations.extend(
            _persistence_violations(
                relative_path,
                path.read_text(encoding="utf-8"),
            )
        )

    assert violations == []


def test_persistence_guard_recognizes_aliases_and_common_write_forms() -> None:
    samples = (
        "from pathlib import Path\nPath('payload').open('w')\n",
        "import json as codec\ncodec.dump({'payload': 1}, sink)\n",
        "from shutil import copyfile as preserve\npreserve('a', 'b')\n",
        "from logging import FileHandler as DiskLog\nDiskLog('events.log')\n",
        "from app.auth import store\nstore.AuthStore(path)\n",
    )

    for source in samples:
        assert _persistence_violations("routes/extract.py", source), source


def test_application_log_calls_match_the_payload_free_allowlist() -> None:
    actual_calls: set[tuple[str, ...]] = set()
    unreviewed_logging: list[str] = []

    for path in _app_sources():
        relative_path = _relative(path)
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        aliases = _import_aliases(tree)
        logger_names = _logger_names(tree, aliases)
        for node in ast.walk(tree):
            if not isinstance(node, ast.Call):
                continue
            qualified_call = _qualified_name(node.func, aliases)
            if qualified_call in {"print", "builtins.print"}:
                unreviewed_logging.append(f"{relative_path}:{node.lineno} calls print()")
                continue
            if qualified_call in DIRECT_DIAGNOSTIC_SINKS:
                unreviewed_logging.append(
                    f"{relative_path}:{node.lineno} calls {qualified_call}()"
                )
                continue
            logger_method: str | None = None
            if (
                isinstance(node.func, ast.Attribute)
                and node.func.attr in LOG_METHODS
                and isinstance(node.func.value, ast.Name)
                and node.func.value.id in logger_names
            ):
                logger_method = node.func.attr
            elif qualified_call is not None and qualified_call.startswith("logging."):
                candidate = qualified_call.rsplit(".", 1)[-1]
                if candidate in LOG_METHODS:
                    logger_method = candidate
            if logger_method is None:
                continue
            if node.keywords:
                unreviewed_logging.append(
                    f"{relative_path}:{node.lineno} uses logging keyword arguments"
                )
                continue
            actual_calls.add(
                (
                    relative_path,
                    logger_method,
                    *(ast.unparse(argument) for argument in node.args),
                )
            )

    assert unreviewed_logging == []
    assert actual_calls == EXPECTED_LOG_CALLS
