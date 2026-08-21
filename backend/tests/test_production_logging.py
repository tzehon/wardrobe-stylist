"""Production-equivalent logging configuration checks."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
LOGGING_CONFIG_PATH = BACKEND_ROOT / "uvicorn-logging.json"


def test_production_logging_config_enables_only_bounded_auth_info() -> None:
    configuration = json.loads(LOGGING_CONFIG_PATH.read_text(encoding="utf-8"))
    loggers = configuration["loggers"]

    assert "root" not in configuration
    assert [name for name in loggers if name.startswith("app.")] == [
        "app.auth.service"
    ]
    assert loggers["app.auth.service"] == {
        "handlers": ["default"],
        "level": "INFO",
        "propagate": False,
    }
    assert loggers["uvicorn.access"]["handlers"] == []
    assert loggers["uvicorn.access"]["propagate"] is False


def test_production_uvicorn_config_emits_security_info_once_without_general_logs() -> None:
    script = """
import logging

from uvicorn import Config

Config(
    "app.main:app",
    access_log=False,
    log_config="uvicorn-logging.json",
).configure_logging()

from app.auth.service import _security_event

_security_event(event="registration_succeeded", mechanism="app_attest")
_security_event(event="assertion_succeeded", mechanism="app_attest")
_security_event(event="installation_deleted", mechanism="app_attest")
_security_event(
    event="installation_rejected",
    code="unknown_app_attest_key",
    mechanism="app_attest",
    level=logging.WARNING,
)
logging.getLogger("app.routes.recommend").info("general_app_info_must_stay_disabled")
logging.getLogger("app.routes.recommend").warning(
    "stylist_failure code=invalid_model_response"
)
logging.getLogger("uvicorn.access").info("access_log_must_stay_disabled")
"""
    result = subprocess.run(
        [sys.executable, "-c", script],
        cwd=BACKEND_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    combined_output = result.stdout + result.stderr

    assert combined_output.count("event=registration_succeeded") == 1
    assert combined_output.count("event=assertion_succeeded") == 1
    assert combined_output.count("event=installation_deleted") == 1
    assert combined_output.count("event=installation_rejected") == 1
    assert combined_output.count("stylist_failure code=invalid_model_response") == 1
    assert "general_app_info_must_stay_disabled" not in combined_output
    assert "access_log_must_stay_disabled" not in combined_output
