"""End-to-end tests for POST /recommend with a faked Anthropic client.

Covers: success path + call shape, the id-validity guard (hallucinated ids
dropped, unsalvageable primary -> 502), schema-validation failure -> 502, auth,
and the missing-tool-call defensive path.
"""

import json
from pathlib import Path

import anthropic
import httpx
import jsonschema
import pytest

from app.agents.stylist import StylistError
from tests.conftest import (
    FakeAnthropicClient,
    FakeResponse,
    make_tool_use_block,
)

# A small catalog the model can reference by id.
A = "11111111-1111-4111-8111-111111111111"
B = "22222222-2222-4222-8222-222222222222"
C = "33333333-3333-4333-8333-333333333333"
D = "44444444-4444-4444-8444-444444444444"

CATALOG = [
    {"id": A, "name": "Oversized Tee", "category": "top", "colors": ["white"]},
    {"id": B, "name": "Slim Trouser", "category": "bottom", "colors": ["navy"]},
    {"id": C, "name": "Suede Loafers", "category": "shoe", "colors": ["tan"]},
    {"id": D, "name": "Denim Jacket", "category": "outerwear", "colors": ["indigo"]},
]


def _queue(fake: FakeAnthropicClient, tool_input: dict) -> None:
    fake.messages.queue(
        FakeResponse(content=[make_tool_use_block("propose_outfit", tool_input)])
    )


def _request_body(**overrides) -> dict:
    body = {
        "items": CATALOG,
        "recently_worn_ids": [D],
        "item_preferences": [
            {"id": A, "average_rating": 4.5, "rating_count": 2},
        ],
        "occasion": "relaxed weekend",
    }
    body.update(overrides)
    return body


def test_recommend_returns_structured_outfit(client, fake_anthropic, auth_headers):
    _queue(
        fake_anthropic,
        {
            "occasion": "relaxed weekend",
            "color_story": "soft neutrals",
            "rationale": "The tee keeps the trouser easy; suede warms it up.",
            "item_ids": [A, B, C],
            "alternates": [
                {"item_ids": [A, B, D], "rationale": "Layer the jacket when it cools."},
            ],
        },
    )

    resp = client.post("/recommend", json=_request_body(), headers=auth_headers)
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["item_ids"] == [A, B, C]
    assert body["occasion"] == "relaxed weekend"
    assert len(body["alternates"]) == 1
    assert "usage" in body and "input_tokens" in body["usage"]

    # Verify the call shape — model, cache marker, forced tool choice, catalog in user turn.
    call = fake_anthropic.messages.last_call
    assert call["model"] == "claude-opus-4-8"
    assert call["max_tokens"] == 2048
    assert call["system"][0]["cache_control"] == {"type": "ephemeral"}
    assert call["tool_choice"] == {"type": "tool", "name": "propose_outfit"}
    assert call["tools"][0]["name"] == "propose_outfit"
    user_content = call["messages"][0]["content"]
    assert A in user_content and "Oversized Tee" in user_content
    assert "relaxed weekend" in user_content
    # Recently-worn ids are passed so Aria can avoid repeats.
    assert D in user_content
    assert "Rated item preferences" in user_content
    assert f"id={A}, average=4.50, ratings=2" in user_content


def test_recommend_wire_response_matches_shared_schema(
    client,
    fake_anthropic,
    auth_headers,
):
    _queue(
        fake_anthropic,
        {
            "occasion": "smart office",
            "color_story": "navy and warm tan",
            "rationale": "A clean, balanced work look.",
            "item_ids": [A, B, C],
            "alternates": [],
        },
    )

    response = client.post("/recommend", json=_request_body(), headers=auth_headers)

    assert response.status_code == 200, response.text
    schema_path = (
        Path(__file__).resolve().parents[2]
        / "shared"
        / "schemas"
        / "outfit.schema.json"
    )
    schema = json.loads(schema_path.read_text())
    jsonschema.validate(instance=response.json(), schema=schema)


def test_recommend_rejects_out_of_range_preference(client, fake_anthropic, auth_headers):
    response = client.post(
        "/recommend",
        json=_request_body(
            item_preferences=[{"id": A, "average_rating": 5.1, "rating_count": 1}]
        ),
        headers=auth_headers,
    )
    assert response.status_code == 422


def test_recommend_rejects_preference_outside_catalog(
    client, fake_anthropic, auth_headers
):
    response = client.post(
        "/recommend",
        json=_request_body(
            item_preferences=[
                {
                    "id": "99999999-9999-4999-8999-999999999999",
                    "average_rating": 5,
                    "rating_count": 1,
                }
            ]
        ),
        headers=auth_headers,
    )
    assert response.status_code == 422
    assert fake_anthropic.messages.last_call is None


def test_recommend_rejects_recent_item_outside_catalog(
    client, fake_anthropic, auth_headers
):
    response = client.post(
        "/recommend",
        json=_request_body(
            recently_worn_ids=["99999999-9999-4999-8999-999999999999"]
        ),
        headers=auth_headers,
    )
    assert response.status_code == 422
    assert fake_anthropic.messages.last_call is None


def test_recommend_drops_hallucinated_item_ids(client, fake_anthropic, auth_headers):
    """Ids the caller didn't send are stripped; a salvageable look still returns 200."""
    bogus = "99999999-9999-4999-8999-999999999999"
    _queue(
        fake_anthropic,
        {
            "occasion": "smart office",
            "color_story": "monochrome",
            "rationale": "Clean column.",
            "item_ids": [A, B, bogus],
            "alternates": [
                # Alternate left with a single valid id -> dropped entirely.
                {"item_ids": [C, bogus], "rationale": "nope"},
            ],
        },
    )
    resp = client.post("/recommend", json=_request_body(), headers=auth_headers)
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["item_ids"] == [A, B]  # bogus removed
    assert body["alternates"] == []  # the under-2-item alternate was dropped


def test_recommend_502_when_primary_unsalvageable(client, fake_anthropic, auth_headers):
    """If fewer than 2 primary items survive the guard, fail closed."""
    bogus = "99999999-9999-4999-8999-999999999999"
    _queue(
        fake_anthropic,
        {
            "occasion": "x",
            "color_story": "x",
            "rationale": "x",
            "item_ids": [A, bogus],  # only one valid id remains
            "alternates": [],
        },
    )
    resp = client.post("/recommend", json=_request_body(), headers=auth_headers)
    assert resp.status_code == 502


@pytest.mark.parametrize(
    "malformed_fields",
    [
        {"item_ids": f"{A}{B}"},
        {"item_ids": [A, B, 7]},
        {"alternates": None},
        {"alternates": {"item_ids": [A, B], "rationale": "not an array"}},
        {"alternates": [None]},
        {"alternates": [{"item_ids": f"{A}{B}", "rationale": "bad ids"}]},
    ],
)
def test_recommend_502_on_malformed_nested_tool_shapes(
    client,
    fake_anthropic,
    auth_headers,
    caplog,
    malformed_fields,
):
    private_model_text = "PRIVATE_MALFORMED_MODEL_TEXT_2417"
    tool_input = {
        "occasion": "x",
        "color_story": "x",
        "rationale": private_model_text,
        "item_ids": [A, B],
        "alternates": [],
    }
    tool_input.update(malformed_fields)
    _queue(fake_anthropic, tool_input)

    with caplog.at_level("WARNING", logger="app.routes.recommend"):
        response = client.post("/recommend", json=_request_body(), headers=auth_headers)

    route_log = "\n".join(
        record.getMessage()
        for record in caplog.records
        if record.name == "app.routes.recommend"
    )
    assert response.status_code == 502
    assert response.json()["detail"] == "The AI service returned an unusable response."
    assert route_log == "stylist_failure code=unsalvageable_outfit"
    assert private_model_text not in route_log
    assert private_model_text not in response.text


def test_recommend_502_on_invalid_tool_input(
    client,
    fake_anthropic,
    auth_headers,
    caplog,
):
    """Invalid model output is rejected without logging wardrobe/model text."""
    private_extra_key = "private_wardrobe_note_as_property_name"
    private_model_text = "PRIVATE_MODEL_WARDROBE_TEXT_987"
    _queue(
        fake_anthropic,
        {
            "occasion": "x",
            "color_story": "x",
            "rationale": "valid rationale",
            "item_ids": [A, B],
            "alternates": [],
            private_extra_key: private_model_text,
        },
    )
    with caplog.at_level("WARNING", logger="app.routes.recommend"):
        resp = client.post("/recommend", json=_request_body(), headers=auth_headers)

    assert resp.status_code == 502
    route_log = "\n".join(
        record.getMessage()
        for record in caplog.records
        if record.name == "app.routes.recommend"
    )
    assert "count=1" in route_log
    assert "extra_forbidden" in route_log
    assert private_extra_key not in route_log
    assert private_model_text not in route_log


def test_recommend_502_when_model_omits_tool_call(client, fake_anthropic, auth_headers):
    fake_anthropic.messages.queue(FakeResponse(content=[], stop_reason="end_turn"))
    resp = client.post("/recommend", json=_request_body(), headers=auth_headers)
    assert resp.status_code == 502


def test_recommend_redacts_private_stylist_error(
    client,
    fake_anthropic,
    auth_headers,
    caplog,
    monkeypatch,
):
    private_sentinel = "PRIVATE_WARDROBE_EXCEPTION_TEXT_1357"

    def fail_with_private_error(*_args, **_kwargs):
        raise StylistError(private_sentinel)

    monkeypatch.setattr(
        "app.routes.recommend.stylist.recommend",
        fail_with_private_error,
    )
    with caplog.at_level("WARNING", logger="app.routes.recommend"):
        response = client.post(
            "/recommend",
            json=_request_body(),
            headers=auth_headers,
        )

    route_log = "\n".join(
        record.getMessage()
        for record in caplog.records
        if record.name == "app.routes.recommend"
    )
    assert response.status_code == 502
    assert response.json()["detail"] == "The AI service returned an unusable response."
    assert route_log == "stylist_failure code=invalid_model_response"
    assert private_sentinel not in route_log
    assert private_sentinel not in response.text


def test_recommend_redacts_private_sanitization_error(
    client,
    fake_anthropic,
    auth_headers,
    caplog,
    monkeypatch,
):
    private_sentinel = "PRIVATE_SANITIZATION_EXCEPTION_TEXT_8642"
    _queue(
        fake_anthropic,
        {
            "occasion": "x",
            "color_story": "x",
            "rationale": "x",
            "item_ids": [A, B],
            "alternates": [],
        },
    )

    def fail_with_private_error(*_args, **_kwargs):
        raise StylistError(private_sentinel)

    monkeypatch.setattr(
        "app.routes.recommend._sanitize_outfit",
        fail_with_private_error,
    )
    with caplog.at_level("WARNING", logger="app.routes.recommend"):
        response = client.post(
            "/recommend",
            json=_request_body(),
            headers=auth_headers,
        )

    route_log = "\n".join(
        record.getMessage()
        for record in caplog.records
        if record.name == "app.routes.recommend"
    )
    assert response.status_code == 502
    assert response.json()["detail"] == "The AI service returned an unusable response."
    assert route_log == "stylist_failure code=unsalvageable_outfit"
    assert private_sentinel not in route_log
    assert private_sentinel not in response.text


def test_recommend_redacts_anthropic_status_error(
    client,
    fake_anthropic,
    auth_headers,
    caplog,
    monkeypatch,
):
    private_api_key = "PRIVATE_ANTHROPIC_KEY_VALUE"
    private_catalog = "PRIVATE_WARDROBE_PAYLOAD_VALUE"
    request = httpx.Request(
        "POST",
        "https://api.anthropic.com/v1/messages",
        headers={"x-api-key": private_api_key},
        content=private_catalog,
    )
    response = httpx.Response(
        500,
        headers={"request-id": "req_safe_123"},
        request=request,
    )
    error = anthropic.APIStatusError(
        f"upstream echoed {private_api_key} and {private_catalog}",
        response=response,
        body={"error": private_catalog},
    )

    def fail_safely(**_):
        raise error

    monkeypatch.setattr(fake_anthropic.messages, "create", fail_safely)
    with caplog.at_level("WARNING", logger="app.anthropic_safety"):
        api_response = client.post(
            "/recommend",
            json=_request_body(),
            headers=auth_headers,
        )

    assert api_response.status_code == 502
    assert api_response.json()["detail"] == "The AI service is temporarily unavailable."
    log = "\n".join(
        record.getMessage()
        for record in caplog.records
        if record.name == "app.anthropic_safety"
    )
    assert "type=APIStatusError status=500 request_id=req_safe_123" in log
    assert private_api_key not in log
    assert private_catalog not in log
    assert private_api_key not in api_response.text
    assert private_catalog not in api_response.text


def test_recommend_rejects_unauthorized(client, fake_anthropic):
    resp = client.post("/recommend", json=_request_body())
    assert resp.status_code == 401


def test_recommend_rejects_wrong_bearer(client, fake_anthropic):
    resp = client.post(
        "/recommend",
        json=_request_body(),
        headers={"Authorization": "Bearer not-the-real-token"},
    )
    assert resp.status_code == 401


def test_recommend_rejects_tiny_catalog(client, fake_anthropic, auth_headers):
    """The request model requires at least 2 catalog items."""
    resp = client.post(
        "/recommend",
        json={"items": [CATALOG[0]], "recently_worn_ids": []},
        headers=auth_headers,
    )
    assert resp.status_code == 422
