"""Pinned-model and SDK v1 integration checks; all provider transport is local."""

import json
from copy import deepcopy

import anthropic
import httpx2
import pytest
from pydantic import ValidationError

from app.agents import stylist
from app.schemas.recommendation import OutfitRecommendation
from tests.conftest import FakeResponse, FakeUsage, make_tool_use_block

INPUT = {
    "items": [
        {"id": "fictional-top", "name": "Fictional cotton shirt", "category": "top"},
        {"id": "fictional-bottom", "name": "Fictional trousers", "category": "bottom"},
    ],
    "recently_worn_ids": [],
    "item_preferences": [],
    "occasion": "fictional afternoon",
}
OUTFIT = {
    "occasion": "afternoon",
    "color_story": "Quiet neutrals.",
    "rationale": "An easy pairing.",
    "item_ids": ["fictional-top", "fictional-bottom"],
    "alternates": [],
}


def test_locked_sdk_sends_one_synchronous_bounded_messages_request():
    requests = []

    def handle(request):
        requests.append(request)
        return httpx2.Response(
            200,
            json={
                "id": "msg_fictional",
                "type": "message",
                "role": "assistant",
                "model": stylist.MODEL,
                "stop_reason": "tool_use",
                "stop_sequence": None,
                "content": [{
                    "type": "tool_use", "id": "tool_fictional",
                    "name": "propose_outfit", "input": OUTFIT,
                }],
                "usage": {"input_tokens": 110, "output_tokens": 90},
            },
        )

    with anthropic.Anthropic(
        api_key="fictional-key",
        max_retries=0,
        http_client=httpx2.Client(transport=httpx2.MockTransport(handle)),
    ) as client:
        result = stylist.recommend(client, **INPUT)

    assert len(requests) == 1
    assert requests[0].method == "POST"
    assert requests[0].url.path == "/v1/messages"
    body = json.loads(requests[0].content)
    assert body["model"] == "claude-haiku-4-5-20251001"
    assert body["max_tokens"] == 1024
    assert body["thinking"] == {"type": "disabled"}
    assert body["tool_choice"] == {
        "type": "tool", "name": "propose_outfit", "disable_parallel_tool_use": True,
    }
    assert body["tools"][0]["strict"] is True
    assert "cache_control" not in body["system"][0]
    assert body["system"] == [{"type": "text", "text": stylist.SYSTEM_PROMPT}]
    for rule in (
        "Every primary and alternate look must be complete",
        "Outerwear never replaces",
        "unordered sets of item ids",
        "past outfit combinations are unknown",
        "Adding or removing an optional catalog bag, jewelry item, or accessory",
        "Before returning no alternates, check suitable item substitutions",
        "Every look must still satisfy the occasion and completeness requirements",
        "contain 2–8 catalog items",
    ):
        assert rule in body["system"][0]["text"]
    alternates_description = body["tools"][0]["input_schema"]["properties"]["alternates"][
        "description"
    ]
    assert "provide at least 1" in alternates_description
    assert (
        "adding or removing an optional bag, jewelry item, or accessory" in alternates_description
    )
    assert "Use 0 only when no valid distinct complete alternate exists" in alternates_description
    assert "item history only; past combinations unknown" in body["messages"][0]["content"]
    assert "stream" not in body or body["stream"] is False
    assert result["tool_input"] == OUTFIT
    assert result["usage"] == {
        "input_tokens": 110, "output_tokens": 90,
        "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0,
    }


def test_cache_probe_marks_static_prefix_only_and_preserves_reported_usage():
    uncached = stylist.build_message_params(**INPUT)
    cached = stylist.build_message_params(**INPUT, cache_mode="ephemeral")
    marker = cached["system"][0].pop("cache_control")
    assert marker == {"type": "ephemeral", "ttl": "5m"}
    assert cached == uncached
    assert "fictional-top" not in json.dumps(cached["system"] + cached["tools"])
    assert "fictional-top" in cached["messages"][0]["content"]
    result = stylist.extract_response(FakeResponse(
        content=[make_tool_use_block("propose_outfit", OUTFIT)],
        usage=FakeUsage(30, 90, 4300, 4200),
    ))
    assert result["usage"] == {
        "input_tokens": 30, "output_tokens": 90,
        "cache_creation_input_tokens": 4300, "cache_read_input_tokens": 4200,
    }


def test_strict_schema_omits_provider_unsupported_bounds_but_local_bounds_remain():
    schema = stylist.PROPOSE_OUTFIT_TOOL["input_schema"]

    def verify(node):
        if isinstance(node, dict):
            assert not {"minItems", "maxItems", "minLength", "maxLength"} & node.keys()
            if node.get("type") == "object":
                assert node["additionalProperties"] is False
                assert set(node["required"]) == set(node["properties"])
            for value in node.values():
                verify(value)
        elif isinstance(node, list):
            for value in node:
                verify(value)

    verify(schema)
    for ids in (["only-one"], [f"item-{index}" for index in range(9)]):
        invalid = {**OUTFIT, "item_ids": ids}
        with pytest.raises(ValidationError):
            OutfitRecommendation.model_validate(invalid)
    with pytest.raises(ValidationError):
        OutfitRecommendation.model_validate({
            **OUTFIT,
            "alternates": [{"item_ids": OUTFIT["item_ids"], "rationale": "Alternate."}] * 5,
        })


@pytest.mark.parametrize("stop_reason", ["max_tokens", "refusal", "end_turn", None])
def test_incomplete_or_refused_tool_results_are_rejected_without_retry(stop_reason):
    response = FakeResponse(
        content=[make_tool_use_block("propose_outfit", OUTFIT)],
        stop_reason=stop_reason,
    )
    with pytest.raises(stylist.StylistError):
        stylist.extract_response(response)


@pytest.mark.parametrize("names", [[], ["wrong_tool"], ["propose_outfit"] * 2,
                                   ["propose_outfit", "wrong_tool"]])
def test_missing_wrong_or_multiple_tools_are_rejected(names):
    response = FakeResponse(content=[make_tool_use_block(name, OUTFIT) for name in names])
    with pytest.raises(stylist.StylistError):
        stylist.extract_response(response)


@pytest.mark.parametrize("limit", [0, 255, 2049, 200000, True, 1024.0])
def test_output_limit_configuration_is_bounded(limit):
    with pytest.raises(ValueError):
        stylist.build_message_params(**INPUT, max_tokens=limit)


def test_invalid_cache_mode_fails_before_provider_request():
    with pytest.raises(ValueError):
        stylist.build_message_params(**INPUT, cache_mode="forever")


def test_request_construction_cannot_mutate_future_tool_schema():
    original = deepcopy(stylist.PROPOSE_OUTFIT_TOOL)
    params = stylist.build_message_params(**INPUT)
    params["tools"][0]["input_schema"]["properties"].clear()
    assert stylist.PROPOSE_OUTFIT_TOOL == original
