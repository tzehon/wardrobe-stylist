"""Enrollment, replay, session, bridge, and quota tests."""

import base64
import hashlib
import json
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
from cryptography.exceptions import UnsupportedAlgorithm

from app.auth.app_attest import AssertionResult, AttestationResult
from app.auth.config import AuthConfiguration
from app.auth.service import (
    AppAttestAuthService,
    AuthFlowError,
    _validate_assertion_client_data,
)

KEY_ID = base64.b64encode(bytes(range(32))).decode("ascii")
ATTESTATION = base64.b64encode(b"test-attestation-object").decode("ascii")
ASSERTION = base64.b64encode(b"test-assertion-object").decode("ascii")


@dataclass
class Clock:
    value: datetime

    def __call__(self) -> datetime:
        return self.value


class FakeVerifier:
    def __init__(self) -> None:
        self.attestation_calls = 0
        self.assertion_calls = 0

    def verify_attestation(self, **_: object) -> AttestationResult:
        self.attestation_calls += 1
        return AttestationResult(
            public_key_der=b"test-public-key",
            opaque_receipt=b"test-apple-receipt",
            validation_category=3,
            bundle_version="7",
        )

    def verify_assertion(self, *, previous_sign_count: int, **_: object) -> AssertionResult:
        self.assertion_calls += 1
        return AssertionResult(
            sign_count=previous_sign_count + 1,
            validation_category=3,
            bundle_version="7",
        )


class UnsupportedAlgorithmVerifier(FakeVerifier):
    def verify_attestation(self, **_: object) -> AttestationResult:
        raise UnsupportedAlgorithm("unsupported test certificate algorithm")


def test_enroll_session_authenticate_and_recover_lost_registration_response(tmp_path) -> None:
    service, verifier, _ = _service(tmp_path)
    challenge = service.issue_challenge(
        purpose="attestation",
        key_id=None,
        client_ip="192.0.2.10",
    )
    enrolled = service.register(
        challenge_id=challenge.challenge_id,
        key_id=KEY_ID,
        attestation_object=ATTESTATION,
        client_ip="192.0.2.10",
    )

    identity = service.authenticate_bearer(
        token=enrolled.access_token,
        path="/extract",
        client_ip="192.0.2.10",
    )
    assert identity.installation_id == enrolled.installation_id
    assert identity.mechanism == "app_attest"
    assert verifier.attestation_calls == 1

    # Replaying the completed attestation never returns or extends a bearer.
    with pytest.raises(AuthFlowError) as replay:
        service.register(
            challenge_id=challenge.challenge_id,
            key_id=KEY_ID,
            attestation_object=ATTESTATION,
            client_ip="192.0.2.10",
        )
    assert replay.value.status_code == 409
    assert replay.value.code == "app_attest_key_already_registered"

    # A client that lost the registration response proves current private-key
    # possession with a fresh assertion instead.
    assertion_challenge = service.issue_challenge(
        purpose="assertion",
        key_id=KEY_ID,
        client_ip="192.0.2.10",
    )
    client_data = _client_data(assertion_challenge, KEY_ID)
    refreshed = service.create_session(
        challenge_id=assertion_challenge.challenge_id,
        key_id=KEY_ID,
        assertion_object=ASSERTION,
        client_data=base64.b64encode(client_data).decode("ascii"),
        client_ip="192.0.2.10",
    )
    assert refreshed.installation_id == enrolled.installation_id
    assert refreshed.access_token != enrolled.access_token
    assert verifier.assertion_calls == 1

    with pytest.raises(AuthFlowError) as assertion_replay:
        service.create_session(
            challenge_id=assertion_challenge.challenge_id,
            key_id=KEY_ID,
            assertion_object=ASSERTION,
            client_data=base64.b64encode(client_data).decode("ascii"),
            client_ip="192.0.2.10",
        )
    assert assertion_replay.value.code == "challenge_already_used"


@pytest.mark.parametrize(
    "mutate",
    [
        lambda value: b" " + value,
        lambda value: value.replace(b'"challenge":', b'"version":1,"challenge":').replace(
            b',"version":1', b"", 1
        ),
        lambda value: value[:-1] + b',"version":1}',
    ],
    ids=["whitespace", "reordered", "duplicate-field"],
)
def test_assertion_client_data_must_be_byte_canonical(tmp_path, mutate) -> None:
    service, verifier, _ = _service(tmp_path)
    _enroll(service)
    challenge = service.issue_challenge(
        purpose="assertion",
        key_id=KEY_ID,
        client_ip="192.0.2.20",
    )
    canonical = _client_data(challenge, KEY_ID)

    with pytest.raises(AuthFlowError) as rejected:
        service.create_session(
            challenge_id=challenge.challenge_id,
            key_id=KEY_ID,
            assertion_object=ASSERTION,
            client_data=base64.b64encode(mutate(canonical)).decode("ascii"),
            client_ip="192.0.2.20",
        )
    assert rejected.value.code == "invalid_app_attest_assertion"
    assert verifier.assertion_calls == 0


def test_unknown_and_noncanonical_key_ids_are_rejected(tmp_path) -> None:
    service, _, _ = _service(tmp_path)
    with pytest.raises(AuthFlowError) as unknown:
        service.issue_challenge(
            purpose="assertion",
            key_id=KEY_ID,
            client_ip="192.0.2.30",
        )
    assert unknown.value.code == "unknown_app_attest_key"

    with pytest.raises(AuthFlowError) as noncanonical:
        service.issue_challenge(
            purpose="assertion",
            key_id=KEY_ID + "=",
            client_ip="192.0.2.30",
        )
    assert noncanonical.value.code in {"invalid_base64", "invalid_key_id"}


def test_assertion_client_data_cross_contract_vector_keeps_slashes_unescaped() -> None:
    key_id = base64.b64encode(b"\xff" * 32).decode("ascii")
    vector = (
        b'{"challenge":"abc_DEF","challenge_id":"11111111-1111-4111-8111-111111111111",'
        b'"key_id":"//////////////////////////////////////////8=","purpose":"assertion",'
        b'"version":1}'
    )
    _validate_assertion_client_data(
        vector,
        challenge_id="11111111-1111-4111-8111-111111111111",
        challenge="abc_DEF",
        key_id=key_id,
    )
    with pytest.raises(ValueError, match="canonical"):
        _validate_assertion_client_data(
            vector.replace(b"/", b"\\/"),
            challenge_id="11111111-1111-4111-8111-111111111111",
            challenge="abc_DEF",
            key_id=key_id,
        )


def test_session_expires_without_server_restart(tmp_path) -> None:
    service, _, clock = _service(tmp_path, session_ttl_seconds=60)
    session = _enroll(service)
    clock.value += timedelta(seconds=61)

    with pytest.raises(AuthFlowError) as expired:
        service.authenticate_bearer(
            token=session.access_token,
            path="/extract",
            client_ip="192.0.2.40",
        )
    assert expired.value.code == "invalid_or_expired_session"


def test_invalid_bearer_exhausts_endpoint_ip_quota_with_retry_after(tmp_path) -> None:
    service, _, _ = _service(tmp_path, extract_rate_limit_per_hour=1)

    with pytest.raises(AuthFlowError) as invalid:
        service.authenticate_bearer(
            token="invalid-session-token",
            path="/extract",
            client_ip="192.0.2.41",
        )
    assert invalid.value.status_code == 401

    with pytest.raises(AuthFlowError) as limited:
        service.authenticate_bearer(
            token="another-invalid-session-token",
            path="/extract",
            client_ip="192.0.2.41",
        )
    assert limited.value.status_code == 429
    assert limited.value.retry_after is not None
    assert 1 <= limited.value.retry_after <= 3600


def test_app_session_is_limited_by_ip_and_installation(tmp_path) -> None:
    service, _, _ = _service(tmp_path, recommend_rate_limit_per_hour=1)
    session = _enroll(service)
    service.authenticate_bearer(
        token=session.access_token,
        path="/recommend",
        client_ip="192.0.2.50",
    )

    with pytest.raises(AuthFlowError) as ip_limited:
        service.authenticate_bearer(
            token=session.access_token,
            path="/recommend",
            client_ip="192.0.2.50",
        )
    assert ip_limited.value.status_code == 429

    with pytest.raises(AuthFlowError) as installation_limited:
        service.authenticate_bearer(
            token=session.access_token,
            path="/recommend",
            client_ip="192.0.2.51",
        )
    assert installation_limited.value.status_code == 429


def test_legacy_bridge_is_ip_limited_and_expires_at_runtime(tmp_path) -> None:
    clock = Clock(datetime(2026, 8, 16, tzinfo=UTC))
    config = _configuration(
        tmp_path,
        mode="bridge",
        legacy_bridge_expires_at=clock.value + timedelta(minutes=5),
        recommend_rate_limit_per_hour=1,
    )
    service = AppAttestAuthService(
        configuration=config,
        legacy_device_token="temporary-legacy-token",
        now=clock,
        verifier=FakeVerifier(),
    )
    service.initialize()
    app_session = _enroll(service)

    identity = service.authenticate_bearer(
        token="temporary-legacy-token",
        path="/recommend",
        client_ip="192.0.2.60",
    )
    assert identity.mechanism == "legacy"
    with pytest.raises(AuthFlowError) as limited:
        service.authenticate_bearer(
            token="temporary-legacy-token",
            path="/recommend",
            client_ip="192.0.2.60",
        )
    assert limited.value.status_code == 429

    clock.value += timedelta(minutes=6)
    app_identity = service.authenticate_bearer(
        token=app_session.access_token,
        path="/extract",
        client_ip="192.0.2.62",
    )
    assert app_identity.mechanism == "app_attest"
    with pytest.raises(AuthFlowError) as expired:
        service.authenticate_bearer(
            token="temporary-legacy-token",
            path="/extract",
            client_ip="192.0.2.61",
        )
    assert expired.value.code == "invalid_or_expired_session"


def test_legacy_bridge_rejects_non_ascii_bearer_without_type_error(tmp_path) -> None:
    clock = Clock(datetime(2026, 8, 16, tzinfo=UTC))
    service = AppAttestAuthService(
        configuration=_configuration(
            tmp_path,
            mode="bridge",
            legacy_bridge_expires_at=clock.value + timedelta(minutes=5),
        ),
        legacy_device_token="temporary-legacy-token-value-32-bytes",
        now=clock,
        verifier=FakeVerifier(),
    )
    service.initialize()

    with pytest.raises(AuthFlowError) as rejected:
        service.authenticate_bearer(
            token="not-the-token-雪",
            path="/extract",
            client_ip="192.0.2.63",
        )
    assert rejected.value.code == "invalid_or_expired_session"


@pytest.mark.parametrize(
    ("stored_app_id", "stored_environment"),
    [
        ("OTHERPREFIX.com.tth.Wardrobe", "production"),
        ("PRODPREFIX.com.tth.Wardrobe", "development"),
    ],
    ids=["wrong-app-id", "development-row-in-production"],
)
def test_restored_installation_must_match_current_app_and_environment(
    tmp_path,
    stored_app_id: str,
    stored_environment: str,
) -> None:
    clock = Clock(datetime(2026, 8, 16, tzinfo=UTC))
    service = AppAttestAuthService(
        configuration=_configuration(
            tmp_path,
            deployment_environment="production",
            app_id_prefix="PRODPREFIX",
            app_attest_environment="production",
            allowed_validation_categories=frozenset({2, 4}),
        ),
        legacy_device_token="",
        now=clock,
        verifier=FakeVerifier(),
    )
    service.initialize()
    assert service.store is not None
    now = int(clock.value.timestamp())
    bearer = "restored-session-token"
    service.store.issue_challenge(
        challenge_id="restored-registration",
        secret=b"r" * 32,
        purpose="attestation",
        key_id=None,
        expires_at=now + 300,
        now=now,
    )
    service.store.claim_challenge(
        challenge_id="restored-registration",
        purpose="attestation",
        key_id=None,
        payload_hash=b"payload",
        now=now,
    )
    service.store.complete_registration(
        challenge_id="restored-registration",
        installation_id="restored-installation",
        key_id=KEY_ID,
        public_key_der=b"public",
        opaque_receipt=b"opaque-apple-receipt",
        app_id=stored_app_id,
        attest_environment=stored_environment,
        validation_category=None,
        bundle_version=None,
        session_id="restored-session",
        token_hash=hashlib.sha256(bearer.encode("ascii")).digest(),
        session_expires_at=now + 900,
        now=now,
    )

    with pytest.raises(AuthFlowError) as challenge_rejected:
        service.issue_challenge(
            purpose="assertion",
            key_id=KEY_ID,
            client_ip="192.0.2.64",
        )
    assert challenge_rejected.value.code == "unknown_app_attest_key"

    service.store.issue_challenge(
        challenge_id="restored-assertion",
        secret=b"a" * 32,
        purpose="assertion",
        key_id=KEY_ID,
        expires_at=now + 300,
        now=now,
    )
    with pytest.raises(AuthFlowError) as assertion_rejected:
        service.create_session(
            challenge_id="restored-assertion",
            key_id=KEY_ID,
            assertion_object=ASSERTION,
            client_data=base64.b64encode(b"{}").decode("ascii"),
            client_ip="192.0.2.65",
        )
    assert assertion_rejected.value.code == "unknown_app_attest_key"

    with pytest.raises(AuthFlowError) as bearer_rejected:
        service.authenticate_bearer(
            token=bearer,
            path="/extract",
            client_ip="192.0.2.66",
        )
    assert bearer_rejected.value.code == "unknown_app_attest_key"


def test_unsupported_attestation_algorithm_fails_as_invalid_attestation(tmp_path) -> None:
    clock = Clock(datetime(2026, 8, 16, tzinfo=UTC))
    service = AppAttestAuthService(
        configuration=_configuration(tmp_path),
        legacy_device_token="",
        now=clock,
        verifier=UnsupportedAlgorithmVerifier(),
    )
    service.initialize()
    challenge = service.issue_challenge(
        purpose="attestation",
        key_id=None,
        client_ip="192.0.2.67",
    )

    with pytest.raises(AuthFlowError) as rejected:
        service.register(
            challenge_id=challenge.challenge_id,
            key_id=KEY_ID,
            attestation_object=ATTESTATION,
            client_ip="192.0.2.67",
        )
    assert rejected.value.code == "invalid_app_attestation"


def test_auth_security_event_logs_are_bounded_and_payload_free(tmp_path, caplog) -> None:
    private_ip = "198.51.100.247"
    service, _, _ = _service(tmp_path, recommend_rate_limit_per_hour=1)

    with caplog.at_level("INFO", logger="app.auth.service"):
        registration_challenge = service.issue_challenge(
            purpose="attestation",
            key_id=None,
            client_ip=private_ip,
        )
        registered = service.register(
            challenge_id=registration_challenge.challenge_id,
            key_id=KEY_ID,
            attestation_object=ATTESTATION,
            client_ip=private_ip,
        )
        assertion_challenge = service.issue_challenge(
            purpose="assertion",
            key_id=KEY_ID,
            client_ip=private_ip,
        )
        client_data = _client_data(assertion_challenge, KEY_ID)
        refreshed = service.create_session(
            challenge_id=assertion_challenge.challenge_id,
            key_id=KEY_ID,
            assertion_object=ASSERTION,
            client_data=base64.b64encode(client_data).decode("ascii"),
            client_ip=private_ip,
        )
        service.authenticate_bearer(
            token=refreshed.access_token,
            path="/recommend",
            client_ip=private_ip,
        )
        with pytest.raises(AuthFlowError):
            service.authenticate_bearer(
                token=refreshed.access_token,
                path="/recommend",
                client_ip=private_ip,
            )

    messages = [
        record.getMessage()
        for record in caplog.records
        if record.name == "app.auth.service"
    ]
    combined = "\n".join(messages)
    assert "event=registration_succeeded" in combined
    assert "event=assertion_succeeded" in combined
    assert "event=rate_limit_exceeded" in combined
    assert all(message.startswith("auth_security_event event=") for message in messages)
    sensitive_values = {
        private_ip,
        KEY_ID,
        ATTESTATION,
        ASSERTION,
        registration_challenge.challenge_id,
        assertion_challenge.challenge_id,
        registered.access_token,
        refreshed.access_token,
        refreshed.installation_id,
        "test-apple-receipt",
    }
    assert all(value not in combined for value in sensitive_values)


def test_challenge_rate_limit_has_retry_after(tmp_path) -> None:
    service, _, _ = _service(tmp_path, challenge_rate_limit_per_minute=1)
    service.issue_challenge(
        purpose="attestation",
        key_id=None,
        client_ip="192.0.2.70",
    )
    with pytest.raises(AuthFlowError) as limited:
        service.issue_challenge(
            purpose="attestation",
            key_id=None,
            client_ip="192.0.2.70",
        )
    assert limited.value.status_code == 429
    assert limited.value.retry_after is not None
    assert 1 <= limited.value.retry_after <= 60


def test_global_challenge_quota_bounds_rotating_ip_issuance(tmp_path) -> None:
    service, _, _ = _service(tmp_path, challenge_rate_limit_per_minute=1)
    for address in ("192.0.2.80", "192.0.2.81"):
        service.issue_challenge(
            purpose="attestation",
            key_id=None,
            client_ip=address,
        )

    with pytest.raises(AuthFlowError) as globally_limited:
        service.issue_challenge(
            purpose="attestation",
            key_id=None,
            client_ip="192.0.2.82",
        )
    assert globally_limited.value.status_code == 429
    assert globally_limited.value.retry_after is not None
    assert 1 <= globally_limited.value.retry_after <= 60


def test_global_registration_quota_bounds_rotating_ip_attempts(tmp_path) -> None:
    service, _, _ = _service(tmp_path, registration_rate_limit_per_hour=1)
    for index, address in enumerate(("192.0.2.83", "192.0.2.84"), start=1):
        with pytest.raises(AuthFlowError) as unknown:
            service.register(
                challenge_id=f"missing-registration-{index}",
                key_id=KEY_ID,
                attestation_object=ATTESTATION,
                client_ip=address,
            )
        assert unknown.value.code == "unknown_challenge"

    with pytest.raises(AuthFlowError) as globally_limited:
        service.register(
            challenge_id="missing-registration-3",
            key_id=KEY_ID,
            attestation_object=ATTESTATION,
            client_ip="192.0.2.85",
        )
    assert globally_limited.value.status_code == 429


def test_global_session_quota_bounds_rotating_ip_attempts(tmp_path) -> None:
    service, _, _ = _service(tmp_path, session_rate_limit_per_hour=1)
    for address in ("192.0.2.86", "192.0.2.87"):
        with pytest.raises(AuthFlowError) as unknown:
            service.create_session(
                challenge_id="00000000-0000-4000-8000-000000000000",
                key_id=KEY_ID,
                assertion_object=ASSERTION,
                client_data=base64.b64encode(b"{}").decode("ascii"),
                client_ip=address,
            )
        assert unknown.value.code == "unknown_app_attest_key"

    with pytest.raises(AuthFlowError) as globally_limited:
        service.create_session(
            challenge_id="00000000-0000-4000-8000-000000000000",
            key_id=KEY_ID,
            assertion_object=ASSERTION,
            client_data=base64.b64encode(b"{}").decode("ascii"),
            client_ip="192.0.2.88",
        )
    assert globally_limited.value.status_code == 429


def test_global_api_attempt_quota_bounds_rotating_ips_before_bearer_lookup(tmp_path) -> None:
    service, _, _ = _service(tmp_path, extract_rate_limit_per_hour=1)
    for address in ("192.0.2.89", "192.0.2.90"):
        with pytest.raises(AuthFlowError) as invalid:
            service.authenticate_bearer(
                token="invalid-session-token",
                path="/extract",
                client_ip=address,
            )
        assert invalid.value.status_code == 401

    with pytest.raises(AuthFlowError) as globally_limited:
        service.authenticate_bearer(
            token="invalid-session-token",
            path="/extract",
            client_ip="192.0.2.91",
        )
    assert globally_limited.value.status_code == 429


def test_invalid_assertion_cannot_exhaust_an_installations_key_quota(tmp_path) -> None:
    service, verifier, _ = _service(tmp_path, session_rate_limit_per_hour=1)
    _enroll(service)

    with pytest.raises(AuthFlowError) as invalid:
        service.create_session(
            challenge_id="00000000-0000-4000-8000-000000000000",
            key_id=KEY_ID,
            assertion_object=ASSERTION,
            client_data=base64.b64encode(b"{}").decode("ascii"),
            client_ip="192.0.2.71",
        )
    assert invalid.value.code == "unknown_challenge"
    assert verifier.assertion_calls == 0

    challenge = service.issue_challenge(
        purpose="assertion",
        key_id=KEY_ID,
        client_ip="192.0.2.72",
    )
    renewed = service.create_session(
        challenge_id=challenge.challenge_id,
        key_id=KEY_ID,
        assertion_object=ASSERTION,
        client_data=base64.b64encode(_client_data(challenge, KEY_ID)).decode("ascii"),
        client_ip="192.0.2.72",
    )

    assert renewed.access_token
    assert verifier.assertion_calls == 1


def _service(tmp_path: Path, **configuration_overrides):
    clock = Clock(datetime(2026, 8, 16, tzinfo=UTC))
    verifier = FakeVerifier()
    service = AppAttestAuthService(
        configuration=_configuration(tmp_path, **configuration_overrides),
        legacy_device_token="",
        now=clock,
        verifier=verifier,
    )
    service.initialize()
    return service, verifier, clock


def _configuration(tmp_path: Path, **overrides) -> AuthConfiguration:
    values = {
        "mode": "app_attest",
        "deployment_environment": "dev",
        "app_id_prefix": "TESTPREFIX",
        "bundle_id": "com.tth.Wardrobe",
        "app_attest_environment": "development",
        "database_path": tmp_path / "private" / "auth.sqlite3",
        "session_secret": b"s" * 32,
        "allowed_validation_categories": frozenset({3}),
        "allowed_bundle_versions": frozenset({"7"}),
        "legacy_bridge_expires_at": None,
        "challenge_ttl_seconds": 300,
        "session_ttl_seconds": 900,
        "challenge_rate_limit_per_minute": 30,
        "registration_rate_limit_per_hour": 5,
        "session_rate_limit_per_hour": 60,
        "extract_rate_limit_per_hour": 120,
        "recommend_rate_limit_per_hour": 30,
    }
    values.update(overrides)
    return AuthConfiguration(**values)


def _enroll(service: AppAttestAuthService):
    challenge = service.issue_challenge(
        purpose="attestation",
        key_id=None,
        client_ip="192.0.2.1",
    )
    return service.register(
        challenge_id=challenge.challenge_id,
        key_id=KEY_ID,
        attestation_object=ATTESTATION,
        client_ip="192.0.2.1",
    )


def _client_data(challenge, key_id: str) -> bytes:
    return json.dumps(
        {
            "version": 1,
            "purpose": "assertion",
            "challenge_id": challenge.challenge_id,
            "challenge": challenge.challenge,
            "key_id": key_id,
        },
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")
