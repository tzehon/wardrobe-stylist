"""Wire-contract tests for the public App Attest endpoints."""

from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

from fastapi.testclient import TestClient

from app.auth.runtime import get_auth_service
from app.auth.service import AppSession, AuthFlowError, Challenge
from app.main import app


class StubAuthService:
    def __init__(self) -> None:
        self.configuration = SimpleNamespace(deployment_environment="dev")
        self.error: AuthFlowError | None = None
        self.last_client_ip: str | None = None
        self.last_deletion: dict[str, str] | None = None

    def issue_challenge(self, **kwargs) -> Challenge:
        self.last_client_ip = kwargs["client_ip"]
        if self.error is not None:
            raise self.error
        return Challenge(
            challenge_id="11111111-1111-4111-8111-111111111111",
            challenge="YWJj",
            expires_at=datetime(2026, 8, 16, 0, 5, tzinfo=UTC),
        )

    def register(self, **kwargs) -> AppSession:
        self.last_client_ip = kwargs["client_ip"]
        return self._session()

    def create_session(self, **kwargs) -> AppSession:
        self.last_client_ip = kwargs["client_ip"]
        return self._session()

    def delete_installation(self, **kwargs) -> None:
        self.last_client_ip = kwargs["client_ip"]
        if self.error is not None:
            raise self.error
        self.last_deletion = kwargs

    @staticmethod
    def _session() -> AppSession:
        return AppSession(
            access_token="opaque-session",
            expires_in=900,
            expires_at=datetime(2026, 8, 16, tzinfo=UTC) + timedelta(seconds=900),
            installation_id="22222222-2222-4222-8222-222222222222",
        )


def test_auth_endpoint_wire_contracts_and_extra_field_rejection() -> None:
    service = StubAuthService()
    app.dependency_overrides[get_auth_service] = lambda: service
    client = TestClient(app)
    try:
        challenge = client.post(
            "/auth/app-attest/challenge",
            json={"purpose": "attestation"},
        )
        assert challenge.status_code == 200
        assert challenge.json() == {
            "challenge_id": "11111111-1111-4111-8111-111111111111",
            "challenge": "YWJj",
            "expires_at": "2026-08-16T00:05:00Z",
        }
        assert service.last_client_ip == "testclient"

        registration = client.post(
            "/auth/app-attest/register",
            json={
                "challenge_id": "11111111-1111-4111-8111-111111111111",
                "key_id": "a2V5",
                "attestation_object": "YXR0ZXN0YXRpb24=",
            },
        )
        assert registration.status_code == 200
        assert registration.json()["token_type"] == "Bearer"
        assert registration.json()["expires_in"] == 900
        assert registration.json()["installation_id"] == (
            "22222222-2222-4222-8222-222222222222"
        )
        assert service.last_client_ip == "testclient"

        session = client.post(
            "/auth/app-attest/session",
            json={
                "challenge_id": "11111111-1111-4111-8111-111111111111",
                "key_id": "a2V5",
                "assertion_object": "YXNzZXJ0aW9u",
                "client_data": "e30=",
            },
        )
        assert session.status_code == 200
        assert session.json()["access_token"] == "opaque-session"
        assert service.last_client_ip == "testclient"

        deletion_challenge = client.post(
            "/auth/app-attest/challenge",
            json={"purpose": "deletion", "key_id": "a2V5"},
        )
        assert deletion_challenge.status_code == 200

        deletion = client.post(
            "/auth/app-attest/delete",
            json={
                "challenge_id": "11111111-1111-4111-8111-111111111111",
                "key_id": "a2V5",
                "assertion_object": "YXNzZXJ0aW9u",
                "client_data": "e30=",
            },
        )
        assert deletion.status_code == 204
        assert deletion.content == b""
        assert service.last_deletion == {
            "challenge_id": "11111111-1111-4111-8111-111111111111",
            "key_id": "a2V5",
            "assertion_object": "YXNzZXJ0aW9u",
            "client_data": "e30=",
            "client_ip": "testclient",
        }

        extra = client.post(
            "/auth/app-attest/challenge",
            json={"purpose": "attestation", "unexpected": True},
        )
        assert extra.status_code == 422
        for response in (
            challenge,
            registration,
            session,
            deletion_challenge,
            deletion,
            extra,
        ):
            assert response.headers["cache-control"] == "no-store"
            assert response.headers["pragma"] == "no-cache"
    finally:
        app.dependency_overrides.pop(get_auth_service, None)


def test_auth_error_has_machine_code_and_retry_after() -> None:
    service = StubAuthService()
    service.error = AuthFlowError(
        status_code=429,
        code="rate_limit_exceeded",
        message="Too many requests.",
        retry_after=17,
    )
    app.dependency_overrides[get_auth_service] = lambda: service
    client = TestClient(app)
    try:
        response = client.post(
            "/auth/app-attest/challenge",
            json={"purpose": "attestation"},
        )
        assert response.status_code == 429
        assert response.headers["retry-after"] == "17"
        assert response.json()["detail"] == {
            "code": "rate_limit_exceeded",
            "message": "Too many requests.",
        }
    finally:
        app.dependency_overrides.pop(get_auth_service, None)


def test_deletion_requires_a_key_and_forbids_extra_fields() -> None:
    service = StubAuthService()
    app.dependency_overrides[get_auth_service] = lambda: service
    client = TestClient(app)
    try:
        missing_key = client.post(
            "/auth/app-attest/challenge",
            json={"purpose": "deletion"},
        )
        assert missing_key.status_code == 422

        extra = client.post(
            "/auth/app-attest/delete",
            json={
                "challenge_id": "11111111-1111-4111-8111-111111111111",
                "key_id": "a2V5",
                "assertion_object": "YXNzZXJ0aW9u",
                "client_data": "e30=",
                "unexpected": True,
            },
        )
        assert extra.status_code == 422
        assert service.last_deletion is None
        for response in (missing_key, extra):
            assert response.headers["cache-control"] == "no-store"
            assert response.headers["pragma"] == "no-cache"
    finally:
        app.dependency_overrides.pop(get_auth_service, None)
