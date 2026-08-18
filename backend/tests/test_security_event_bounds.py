"""Runtime bounds for privacy-safe App Attest security events."""

import logging

import pytest

from app.auth.service import _security_event


@pytest.mark.parametrize(
    ("event", "code", "scope", "path", "mechanism", "level"),
    [
        (
            "registration_succeeded",
            "-",
            "-",
            "-",
            "app_attest",
            logging.INFO,
        ),
        (
            "installation_deleted",
            "-",
            "-",
            "-",
            "app_attest",
            logging.INFO,
        ),
        (
            "auth_maintenance_failed",
            "store_maintenance_failed",
            "-",
            "-",
            "app_attest",
            logging.ERROR,
        ),
        (
            "rate_limit_exceeded",
            "rate_limit_exceeded",
            "deletion-challenge-ip",
            "-",
            "-",
            logging.WARNING,
        ),
        (
            "rate_limit_exceeded",
            "rate_limit_exceeded",
            "deletion-challenge-global",
            "-",
            "-",
            logging.WARNING,
        ),
        (
            "rate_limit_exceeded",
            "rate_limit_exceeded",
            "deletion-proof-global",
            "-",
            "-",
            logging.WARNING,
        ),
        (
            "rate_limit_exceeded",
            "rate_limit_exceeded",
            "deletion-proof-ip",
            "-",
            "-",
            logging.WARNING,
        ),
        (
            "rate_limit_exceeded",
            "rate_limit_exceeded",
            "deletion-key",
            "-",
            "-",
            logging.WARNING,
        ),
    ],
)
def test_reviewed_security_event_values_remain_observable(
    caplog: pytest.LogCaptureFixture,
    event: str,
    code: str,
    scope: str,
    path: str,
    mechanism: str,
    level: int,
) -> None:
    with caplog.at_level(logging.INFO, logger="app.auth.service"):
        _security_event(
            event=event,
            code=code,
            scope=scope,
            path=path,
            mechanism=mechanism,
            level=level,
        )

    record = caplog.records[-1]
    assert record.levelno == level
    assert record.getMessage() == (
        f"auth_security_event event={event} code={code} scope={scope} "
        f"path={path} mechanism={mechanism}"
    )


def test_unreviewed_security_event_values_and_level_are_bounded(
    caplog: pytest.LogCaptureFixture,
) -> None:
    private_sentinel = "private-receipt-catalog-token-198.51.100.247"

    with caplog.at_level(logging.INFO, logger="app.auth.service"):
        _security_event(
            event=private_sentinel,
            code=private_sentinel,
            scope=private_sentinel,
            path=private_sentinel,
            mechanism=private_sentinel,
            level=123_456,
        )

    record = caplog.records[-1]
    assert record.levelno == logging.WARNING
    assert private_sentinel not in record.getMessage()
    assert record.getMessage() == ("auth_security_event event=- code=- scope=- path=- mechanism=-")
