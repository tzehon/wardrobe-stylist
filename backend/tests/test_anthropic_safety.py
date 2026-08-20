"""Concurrency-boundary tests for synchronous Anthropic SDK calls."""

import threading

import pytest

import app.anthropic_safety as anthropic_safety
from app.config import settings
from app.dependencies import get_anthropic_client
from tests.test_recommend import _request_body


class _AlwaysSaturated:
    def acquire(self, *, blocking: bool) -> bool:
        assert blocking is False
        return False

    def release(self) -> None:
        raise AssertionError("A rejected request must not release an unowned permit.")


def test_anthropic_client_has_bounded_timeouts_and_retries(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured: dict[str, object] = {}
    sentinel = object()

    def build_client(**kwargs: object) -> object:
        captured.update(kwargs)
        return sentinel

    monkeypatch.setattr(settings, "anthropic_api_key", "private-test-key")
    monkeypatch.setattr(anthropic_safety.anthropic, "Anthropic", build_client)

    assert get_anthropic_client() is sentinel
    timeout = captured["timeout"]
    assert isinstance(timeout, anthropic_safety.anthropic.Timeout)
    assert timeout.connect == 5.0
    assert timeout.read == 120.0
    assert timeout.write == 120.0
    assert timeout.pool == 120.0
    assert captured["max_retries"] == 1
    assert captured["api_key"] == "private-test-key"


def test_anthropic_request_slot_releases_permit_after_exception(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    slots = threading.BoundedSemaphore(1)
    monkeypatch.setattr(anthropic_safety, "_ANTHROPIC_SLOTS", slots)

    with pytest.raises(RuntimeError, match="upstream failure"):
        with anthropic_safety.anthropic_request_slot():
            raise RuntimeError("upstream failure")

    assert slots.acquire(blocking=False) is True
    slots.release()


def test_anthropic_saturation_fails_fast_without_forwarding_private_payload(
    client,
    fake_anthropic,
    auth_headers,
    caplog: pytest.LogCaptureFixture,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(anthropic_safety, "_ANTHROPIC_SLOTS", _AlwaysSaturated())
    request_body = _request_body(occasion="PRIVATE_SATURATION_OCCASION")

    with caplog.at_level("WARNING", logger="app.anthropic_safety"):
        response = client.post("/recommend", json=request_body, headers=auth_headers)

    assert response.status_code == 503
    assert response.json() == {"detail": "The AI service is busy; try again shortly."}
    assert response.headers["retry-after"] == "1"
    assert response.headers["cache-control"] == "no-store"
    assert response.headers["pragma"] == "no-cache"
    assert fake_anthropic.messages.last_call is None

    security_log = "\n".join(
        record.getMessage()
        for record in caplog.records
        if record.name == "app.anthropic_safety"
    )
    assert security_log == "anthropic_concurrency_rejected limit=4"
    assert "PRIVATE_SATURATION" not in security_log
    assert "PRIVATE_SATURATION" not in response.text
