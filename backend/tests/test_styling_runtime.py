"""Exercise the actual API's budget and privacy boundary with a fake provider."""

from copy import deepcopy
from dataclasses import replace
from datetime import UTC, datetime
from pathlib import Path

import anthropic
import httpx2
import pytest
from pydantic import ValidationError

from app import styling_runtime
from app.config import Settings, settings
from app.styling_runtime import get_styling_budget
from tests.conftest import FakeResponse, FakeUsage, make_tool_use_block
from tests.test_recommend import CATALOG, A, B, C, _request_body


def queue_look(fake, **usage):
    fake.messages.queue(
        FakeResponse(
            content=[
                make_tool_use_block(
                    "propose_outfit",
                    {
                        "occasion": "work",
                        "color_story": "blue",
                        "rationale": "A cohesive look.",
                        "item_ids": [A, B, C],
                        "alternates": [],
                    },
                )
            ],
            usage=FakeUsage(**usage),
        )
    )


def test_success_charges_actual_tokens_without_persisting_payload(
    client, fake_anthropic, auth_headers
):
    queue_look(fake_anthropic)
    response = client.post("/recommend", json=_request_body(), headers=auth_headers)
    assert response.status_code == 200
    snapshot = get_styling_budget().snapshot()
    assert snapshot.charged_units == 350
    assert snapshot.admitted_requests == 1
    assert snapshot.active_reservations == 0
    assert b"Oversized Tee" not in Path(settings.ai_budget_database_path).read_bytes()


@pytest.mark.parametrize(
    "field,value",
    [
        ("ai_styling_enabled", False),
        ("ai_budget_database_path", ""),
        ("ai_monthly_unit_limit", 0),
        ("ai_monthly_request_limit", 0),
    ],
)
def test_unapproved_or_disabled_budget_never_calls_provider(
    client, fake_anthropic, auth_headers, monkeypatch, field, value
):
    monkeypatch.setattr(settings, field, value)
    response = client.post("/recommend", json=_request_body(), headers=auth_headers)
    assert response.status_code == 503
    assert fake_anthropic.messages.last_call is None
    assert response.json() == {"detail": "The AI service is temporarily unavailable."}


def test_missing_store_is_not_recreated(
    client,
    fake_anthropic,
    auth_headers,
    monkeypatch,
    tmp_path,
):
    missing = tmp_path / "missing.sqlite3"
    monkeypatch.setattr(settings, "ai_budget_database_path", str(missing))
    assert client.post("/recommend", json=_request_body(), headers=auth_headers).status_code == 503
    assert not missing.exists()
    assert fake_anthropic.messages.last_call is None


@pytest.mark.parametrize("case", ["catalog", "color", "utf8"])
def test_operational_input_caps_leave_wire_schema_and_provider_untouched(
    client,
    fake_anthropic,
    auth_headers,
    case,
):
    body = deepcopy(_request_body())
    if case == "catalog":
        body["items"] = [dict(CATALOG[0], id=str(i)) for i in range(201)]
        body["recently_worn_ids"] = []
        body["item_preferences"] = []
    elif case == "color":
        body["items"][0]["colors"] = ["PRIVATE_COLOR" * 20]
    else:
        body["items"] = [dict(CATALOG[0], id=str(i), name="衣" * 256) for i in range(60)]
        body["recently_worn_ids"] = []
        body["item_preferences"] = []
    response = client.post("/recommend", json=body, headers=auth_headers)
    assert response.status_code == 503
    assert fake_anthropic.messages.last_call is None
    assert "PRIVATE" not in response.text


def test_recommend_body_is_capped_before_parsing(client, fake_anthropic, auth_headers):
    response = client.post("/recommend", content=b" " * (128 * 1024 + 1), headers=auth_headers)
    assert response.status_code == 413
    assert fake_anthropic.messages.last_call is None


def test_connection_uncertainty_keeps_charge_and_slot(
    client, fake_anthropic, auth_headers, monkeypatch
):
    def fail(**kwargs):
        raise anthropic.APIConnectionError(
            request=httpx2.Request("POST", "https://api.anthropic.com")
        )

    monkeypatch.setattr(fake_anthropic.messages, "create", fail)
    assert client.post("/recommend", json=_request_body(), headers=auth_headers).status_code == 503
    snapshot = get_styling_budget().snapshot()
    assert snapshot.charged_units == 205_120
    assert snapshot.active_reservations == 1
    assert snapshot.uncertain_reservations == 1


def test_terminal_unusable_output_keeps_charge_but_releases_slot(
    client, fake_anthropic, auth_headers
):
    fake_anthropic.messages.queue(FakeResponse(content=[], stop_reason="max_tokens"))
    assert client.post("/recommend", json=_request_body(), headers=auth_headers).status_code == 502
    snapshot = get_styling_budget().snapshot()
    assert snapshot.charged_units == 205_120
    assert snapshot.active_reservations == 0


@pytest.mark.parametrize(
    "usage",
    [
        {"input_tokens": 200_001},
        {"output_tokens": 1025},
        {"cache_creation_input_tokens": 1},
        {"cache_read_input_tokens": 1},
        {"input_tokens": True},
    ],
)
def test_unexpected_usage_cannot_refund_reservation(client, fake_anthropic, auth_headers, usage):
    queue_look(fake_anthropic, **usage)
    assert client.post("/recommend", json=_request_body(), headers=auth_headers).status_code == 503
    snapshot = get_styling_budget().snapshot()
    assert snapshot.charged_units >= 205_120
    assert snapshot.active_reservations == 1


@pytest.mark.parametrize(
    "field,value",
    [
        ("ai_monthly_unit_limit", 100_000_001),
        ("ai_monthly_request_limit", 100_001),
        ("ai_max_concurrency", 5),
        ("ai_max_output_tokens", 2049),
        ("ai_max_output_tokens", 255),
    ],
)
def test_configuration_upper_bounds(field, value):
    with pytest.raises(ValidationError):
        Settings(_env_file=None, **{field: value})


def test_default_configuration_is_not_an_approved_budget():
    config = Settings(_env_file=None)
    assert not config.ai_styling_enabled
    assert config.ai_monthly_unit_limit == 0
    assert config.ai_monthly_request_limit == 0


def test_terminal_provider_error_retains_cost_releases_slot(
    client, fake_anthropic, auth_headers, monkeypatch,
):
    def fail(**kwargs):
        raise anthropic.RateLimitError(
            "PRIVATE_PROVIDER_ERROR", response=httpx2.Response(
                429, request=httpx2.Request("POST", "https://api.anthropic.com"),
            ), body=None,
        )
    monkeypatch.setattr(fake_anthropic.messages, "create", fail)
    response = client.post("/recommend", json=_request_body(), headers=auth_headers)
    assert response.status_code == 503
    assert "PRIVATE" not in response.text
    snapshot = get_styling_budget().snapshot()
    assert snapshot.charged_units == 205_120
    assert snapshot.active_reservations == 0


@pytest.mark.parametrize("usage", [None, {}, {"input_tokens": "PRIVATE_USAGE"}])
def test_missing_or_malformed_usage_never_refunds(
    client, auth_headers, monkeypatch, usage,
):
    monkeypatch.setattr("app.routes.recommend.stylist.recommend", lambda *a, **kw: {
        "tool_input": {"occasion": "work", "color_story": "blue", "rationale": "A look.",
                       "item_ids": [A, B, C], "alternates": []}, "usage": usage,
    })
    response = client.post("/recommend", json=_request_body(), headers=auth_headers)
    assert response.status_code == 502
    snapshot = get_styling_budget().snapshot()
    assert snapshot.charged_units == 205_120
    assert snapshot.active_reservations == 0


def test_production_diagnostic_is_redacted_read_only_and_flags_small_rollover(monkeypatch):
    snapshot = get_styling_budget().snapshot()
    monkeypatch.setattr(settings, "environment", "production")
    monkeypatch.setattr(settings, "ai_budget_database_path", "/data/ai-budget/budget.sqlite3")
    monkeypatch.setattr(styling_runtime, "inspect_budget_database", lambda *a, **kw: snapshot)
    result = styling_runtime.production_styling_status()
    assert result == {
        "model": "pinned-haiku", "policy": "bounded", "ledger": "ready",
        "spend_band": "below-warning", "enabled": "yes", "concurrency": "clear",
    }
    old = replace(snapshot, month=200001, unit_limit=100_000)
    monkeypatch.setattr(styling_runtime, "inspect_budget_database", lambda *a, **kw: old)
    assert styling_runtime.production_styling_status()["spend_band"] == "exhausted"
    old = replace(snapshot, month=200001, charged_units=9_900_000)
    assert styling_runtime.production_styling_status()["spend_band"] == "below-warning"
    future = replace(snapshot, month=datetime.now(UTC).year * 100 + 101)
    monkeypatch.setattr(styling_runtime, "inspect_budget_database", lambda *a, **kw: future)
    assert styling_runtime.production_styling_status() == {"unavailable": "yes"}
