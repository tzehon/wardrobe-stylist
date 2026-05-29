"""End-to-end tests for POST /extract with a faked Anthropic client.

Covers: success path, not-fashion path (items dropped), source-id override,
auth, and tool-input schema-validation failure surfacing as 502.
"""

from tests.conftest import (
    FakeAnthropicClient,
    FakeResponse,
    make_tool_use_block,
)


def _queue(fake: FakeAnthropicClient, tool_input: dict) -> None:
    fake.messages.queue(
        FakeResponse(content=[make_tool_use_block("record_purchase", tool_input)])
    )


def test_extract_returns_structured_fashion_purchase(client, fake_anthropic, auth_headers):
    _queue(
        fake_anthropic,
        {
            "is_fashion": True,
            "source_msg_id": "msg_001",
            "items": [
                {
                    "name": "Classic Oxford Shirt",
                    "category": "top",
                    "brand": "Everlane",
                    "color": "white",
                    "material": "cotton",
                    "style_notes": "minimalist",
                    "price": 78.0,
                    "currency": "USD",
                    "image_url": "https://example.com/shirt.jpg",
                    "confidence": "high",
                }
            ],
        },
    )

    resp = client.post(
        "/extract",
        json={
            "source_msg_id": "msg_001",
            "sender": "orders@everlane.com",
            "subject": "Your order is confirmed",
            "snippet": "Thanks for your order. 1x Classic Oxford Shirt - White - $78",
        },
        headers=auth_headers,
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["is_fashion"] is True
    assert body["source_msg_id"] == "msg_001"
    assert len(body["items"]) == 1
    item = body["items"][0]
    assert item["category"] == "top"
    assert item["currency"] == "USD"
    assert item["confidence"] == "high"
    assert "usage" in body and "input_tokens" in body["usage"]

    # Verify the call shape — model, cache marker, forced tool choice.
    call = fake_anthropic.messages.last_call
    assert call["model"] == "claude-haiku-4-5"
    assert call["max_tokens"] == 2048
    assert call["system"][0]["cache_control"] == {"type": "ephemeral"}
    assert call["tool_choice"] == {"type": "tool", "name": "record_purchase"}
    assert call["tools"][0]["name"] == "record_purchase"
    # Source id is in the user message so the model can echo it.
    user_content = call["messages"][0]["content"]
    assert "msg_001" in user_content
    assert "Classic Oxford Shirt" in user_content


def test_extract_drops_items_when_not_fashion(client, fake_anthropic, auth_headers):
    _queue(
        fake_anthropic,
        {
            "is_fashion": False,
            "source_msg_id": "msg_002",
            # Model leaked an item alongside is_fashion=false; the contract says drop it.
            "items": [{"name": "USB-C cable", "category": "accessory", "confidence": "low"}],
        },
    )
    resp = client.post(
        "/extract",
        json={"source_msg_id": "msg_002", "snippet": "Your Apple Store order: 1x USB-C cable"},
        headers=auth_headers,
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["is_fashion"] is False
    assert body["items"] == []


def test_extract_overrides_echoed_source_msg_id(client, fake_anthropic, auth_headers):
    """If the model rewrites or hallucinates the source id, the request id wins."""
    _queue(
        fake_anthropic,
        {
            "is_fashion": True,
            "source_msg_id": "WRONG_ID",
            "items": [{"name": "Shirt", "category": "top", "confidence": "high"}],
        },
    )
    resp = client.post(
        "/extract",
        json={"source_msg_id": "real_msg_id", "snippet": "1x shirt"},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["source_msg_id"] == "real_msg_id"


def test_extract_rejects_unauthorized(client, fake_anthropic):
    resp = client.post(
        "/extract",
        json={"source_msg_id": "msg_x", "snippet": "anything"},
    )
    assert resp.status_code == 401


def test_extract_rejects_wrong_bearer(client, fake_anthropic):
    resp = client.post(
        "/extract",
        json={"source_msg_id": "msg_x", "snippet": "anything"},
        headers={"Authorization": "Bearer not-the-real-token"},
    )
    assert resp.status_code == 401


def test_extract_502_on_invalid_tool_input(client, fake_anthropic, auth_headers):
    """Bad tool input from the model surfaces as 502 — never 200 with garbage."""
    _queue(
        fake_anthropic,
        {
            "is_fashion": True,
            "source_msg_id": "msg_bad",
            "items": [
                {"name": "Shirt", "category": "INVALID_CATEGORY", "confidence": "high"}
            ],
        },
    )
    resp = client.post(
        "/extract",
        json={"source_msg_id": "msg_bad", "snippet": "1x shirt"},
        headers=auth_headers,
    )
    assert resp.status_code == 502


def test_extract_502_when_model_omits_tool_call(client, fake_anthropic, auth_headers):
    """Defensive: stop_reason wasn't tool_use; the route should not crash."""
    fake_anthropic.messages.queue(FakeResponse(content=[], stop_reason="end_turn"))
    resp = client.post(
        "/extract",
        json={"source_msg_id": "msg_empty", "snippet": "n/a"},
        headers=auth_headers,
    )
    assert resp.status_code == 502
