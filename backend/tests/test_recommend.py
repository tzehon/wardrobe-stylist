"""End-to-end tests for POST /recommend with a faked Anthropic client.

Covers: success path + call shape, the id-validity guard (hallucinated ids
dropped, unsalvageable primary -> 502), schema-validation failure -> 502, auth,
and the missing-tool-call defensive path.
"""

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
    body = {"items": CATALOG, "recently_worn_ids": [D], "occasion": "relaxed weekend"}
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


def test_recommend_502_on_invalid_tool_input(client, fake_anthropic, auth_headers):
    """Schema-invalid tool input (blank rationale) surfaces as 502, never 200 with garbage."""
    _queue(
        fake_anthropic,
        {
            "occasion": "x",
            "color_story": "x",
            "rationale": "",  # violates minLength
            "item_ids": [A, B],
            "alternates": [],
        },
    )
    resp = client.post("/recommend", json=_request_body(), headers=auth_headers)
    assert resp.status_code == 502


def test_recommend_502_when_model_omits_tool_call(client, fake_anthropic, auth_headers):
    fake_anthropic.messages.queue(FakeResponse(content=[], stop_reason="end_turn"))
    resp = client.post("/recommend", json=_request_body(), headers=auth_headers)
    assert resp.status_code == 502


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
