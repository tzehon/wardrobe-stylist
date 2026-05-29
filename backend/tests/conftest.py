"""Test fixtures + a minimal stand-in for the Anthropic SDK.

The fake client records the last call (so tests can assert request shape:
model, cache_control, tool_choice) and returns canned tool-use responses.
No network ever leaves the test process.
"""

from collections.abc import Iterator
from dataclasses import dataclass, field
from typing import Any

import pytest
from anthropic.types import ToolUseBlock
from fastapi.testclient import TestClient

from app.config import settings as runtime_settings
from app.dependencies import get_anthropic_client
from app.main import app

TEST_DEVICE_TOKEN = "test-device-token"


@dataclass
class FakeUsage:
    input_tokens: int = 100
    output_tokens: int = 50
    cache_creation_input_tokens: int = 0
    cache_read_input_tokens: int = 0


@dataclass
class FakeResponse:
    content: list[Any]
    usage: FakeUsage = field(default_factory=FakeUsage)
    stop_reason: str = "tool_use"


def make_tool_use_block(name: str, payload: dict[str, Any]) -> ToolUseBlock:
    """Construct a real ToolUseBlock — keeps isinstance checks in the route working."""
    return ToolUseBlock(id="toolu_test", name=name, input=payload, type="tool_use")


class FakeMessagesClient:
    """Stand-in for ``client.messages``. Records the last call; returns the queued response."""

    def __init__(self) -> None:
        self.last_call: dict[str, Any] | None = None
        self._next: FakeResponse | None = None

    def queue(self, response: FakeResponse) -> None:
        self._next = response

    def create(self, **kwargs: Any) -> FakeResponse:
        self.last_call = kwargs
        if self._next is None:
            raise AssertionError(
                "Test forgot to queue a fake response before calling client.messages.create"
            )
        resp, self._next = self._next, None
        return resp


class FakeAnthropicClient:
    def __init__(self) -> None:
        self.messages = FakeMessagesClient()


@pytest.fixture()
def fake_anthropic() -> FakeAnthropicClient:
    return FakeAnthropicClient()


@pytest.fixture()
def client(
    fake_anthropic: FakeAnthropicClient, monkeypatch: pytest.MonkeyPatch
) -> Iterator[TestClient]:
    monkeypatch.setattr(runtime_settings, "device_token", TEST_DEVICE_TOKEN)
    monkeypatch.setattr(runtime_settings, "anthropic_api_key", "test-key-not-used")
    app.dependency_overrides[get_anthropic_client] = lambda: fake_anthropic
    try:
        yield TestClient(app)
    finally:
        app.dependency_overrides.pop(get_anthropic_client, None)


@pytest.fixture()
def auth_headers() -> dict[str, str]:
    return {"Authorization": f"Bearer {TEST_DEVICE_TOKEN}"}
