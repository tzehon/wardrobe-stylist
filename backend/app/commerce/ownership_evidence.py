"""Inactive request inspection, NOT an ownership authorizer or binding store.

An App Attest signature authenticates a request from an installation. It does
not certify that a supplied StoreKit device UUID belongs to that installation.
All inputs/results are volatile. No challenge/counter is consumed here: callers
must not grant access from this result or reuse a stale server-state snapshot.
"""

from __future__ import annotations

import base64
import binascii
import hashlib
import hmac
from dataclasses import dataclass
from uuid import UUID

from app.auth.app_attest import AppAttestVerifier, AssertionResult
from app.auth.store import InstallationRecord
from app.commerce.apple_evidence import MAX_JWS_BYTES, AppEvidence, AppleEvidenceVerifier
from app.schemas.commerce import MAX_TIMESTAMP

DOMAIN = "wardrobe-commerce-app-proof-v1"
MAX_CHALLENGE_LIFETIME_MS = 300_000
MAX_REVISION = 2**53 - 1


class OwnershipEvidenceError(ValueError):
    """Fixed codes only; never include JWS, UUID, key or upstream data."""


def _uuid(value: str) -> str:
    if type(value) is not str or len(value) != 36:
        raise OwnershipEvidenceError("invalid_uuid")
    try:
        parsed = UUID(value)
    except ValueError:
        raise OwnershipEvidenceError("invalid_uuid") from None
    if str(parsed) != value.lower() or parsed.int == 0:
        raise OwnershipEvidenceError("invalid_uuid")
    return str(parsed)


def _integer(value: int, maximum: int = MAX_TIMESTAMP * 1000 + 999) -> int:
    if type(value) is not int or not 0 <= value <= maximum:
        raise OwnershipEvidenceError("invalid_integer")
    return value


def _key_bytes(value: str) -> bytes:
    try:
        if type(value) is not str or len(value) != 44:
            raise ValueError
        result = base64.b64decode(value, validate=True)
        if len(result) != 32 or base64.b64encode(result).decode("ascii") != value:
            raise ValueError
        return result
    except (ValueError, binascii.Error):
        raise OwnershipEvidenceError("invalid_key") from None


@dataclass(frozen=True, repr=False)
class ProofChallenge:
    """Server-owned state snapshot, never reconstructed from a proof request.

    Future storage must bind the generation to the current installation binding,
    and atomically consume the challenge with the shared App Attest counter.
    """

    challenge_id: str
    nonce: bytes
    installation_id: str
    key_id: str
    binding_revision: int
    issued_at_ms: int
    expires_at_ms: int

    def __post_init__(self) -> None:
        _uuid(self.challenge_id)
        _uuid(self.installation_id)
        _key_bytes(self.key_id)
        _integer(self.binding_revision, MAX_REVISION)
        if type(self.nonce) is not bytes or len(self.nonce) != 32:
            raise OwnershipEvidenceError("invalid_challenge")
        if not (0 < _integer(self.expires_at_ms) - _integer(self.issued_at_ms)
                <= MAX_CHALLENGE_LIFETIME_MS):
            raise OwnershipEvidenceError("invalid_challenge")

    def require_fresh(self, now_ms: int) -> None:
        if not self.issued_at_ms <= _integer(now_ms) < self.expires_at_ms:
            raise OwnershipEvidenceError("expired_challenge")


def device_digest(nonce: str, device_id: str) -> bytes:
    """Apple's local comparison only; knowing both UUIDs is not ownership."""
    return hashlib.sha384((_uuid(nonce) + _uuid(device_id)).encode("ascii")).digest()


def proof_transcript(challenge: ProofChallenge, app_jws: str, device_id: str) -> bytes:
    """Fixed-order ASCII lines, ending in LF; mirrored in Swift and golden data."""
    if (type(app_jws) is not str or not app_jws.isascii()
            or not 1 <= len(app_jws) <= MAX_JWS_BYTES):
        raise OwnershipEvidenceError("invalid_jws")
    fields = (
        DOMAIN, _uuid(challenge.challenge_id), challenge.nonce.hex(),
        _uuid(challenge.installation_id), _key_bytes(challenge.key_id).hex(),
        str(challenge.binding_revision), str(challenge.issued_at_ms),
        str(challenge.expires_at_ms), hashlib.sha256(app_jws.encode("ascii")).hexdigest(),
        _uuid(device_id),
    )
    return ("\n".join(fields) + "\n").encode("ascii")


@dataclass(frozen=True, repr=False)
class InspectedAppRequest:
    """Signature/claim inspection result, never an owner, grant or committed proof."""

    app: AppEvidence
    assertion: AssertionResult


def inspect_app_request(
    *, challenge: ProofChallenge, installation: InstallationRecord,
    app_jws: str, device_id: str, assertion_object: bytes,
    apple: AppleEvidenceVerifier, attest: AppAttestVerifier,
) -> InspectedAppRequest:
    """Inspect one request using TRUSTED server challenge/installation snapshots.

    No independent device-origin guarantee follows from a matching UUID digest.
    Replay exclusion and binding changes require a future durable transaction.
    The clock is the trusted Apple verifier's server clock, checked again after
    online verification. Errors deliberately discard potentially private causes.
    """
    try:
        started = _integer(apple.clock_ms())
        challenge.require_fresh(started)
        if (installation.installation_id != challenge.installation_id
                or installation.key_id != challenge.key_id
                or installation.revoked_at is not None
                or installation.app_id != attest.app_id
                or installation.attest_environment != attest.environment
                or not attest.app_id.endswith("." + apple.policy.bundle_id)):
            raise OwnershipEvidenceError("installation_mismatch")
        if type(assertion_object) is not bytes or not 1 <= len(assertion_object) <= 8192:
            raise OwnershipEvidenceError("invalid_assertion")
        transcript = proof_transcript(challenge, app_jws, device_id)
        assertion = attest.verify_assertion(
            assertion_object=assertion_object, client_data=transcript,
            public_key_der=installation.public_key_der,
            previous_sign_count=installation.sign_count,
        )
        # Only pay the SDK's online-verification cost after installation proof.
        app = apple.verify_app(app_jws)
        expected = device_digest(app.device_verification_nonce, device_id)
        if not hmac.compare_digest(expected, app.device_verification):
            raise OwnershipEvidenceError("device_mismatch")
        finished = _integer(apple.clock_ms())
        if finished < started:
            raise OwnershipEvidenceError("invalid_clock")
        challenge.require_fresh(finished)
        return InspectedAppRequest(app, assertion)
    except OwnershipEvidenceError:
        raise
    except Exception:
        raise OwnershipEvidenceError("verification_failed") from None
