"""App Attest enrollment, assertion sessions, and request authorization."""

from __future__ import annotations

import asyncio
import base64
import binascii
import hashlib
import hmac
import json
import logging
import secrets
import uuid
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any, Literal, NoReturn

from cryptography import x509
from cryptography.exceptions import UnsupportedAlgorithm

from app.auth.app_attest import AppAttestValidationError, AppAttestVerifier
from app.auth.config import AuthConfiguration
from app.auth.store import (
    AuthStore,
    DeletionMaintenancePending,
    InstallationRecord,
    InstallationWritePolicy,
    RateLimitExceeded,
    SessionRecord,
    StoreConflictError,
)

ChallengePurpose = Literal["attestation", "assertion", "deletion"]
logger = logging.getLogger(__name__)

# One installation normally shares one public IP. A 2x aggregate allowance
# tolerates ordinary IP changes and overlapping retries while preventing a
# distributed caller from multiplying every per-IP budget by hundreds of
# source addresses. These constant-subject buckets are charged first.
_GLOBAL_RATE_LIMIT_MULTIPLIER = 2
_GLOBAL_RATE_SUBJECT = "single-user-backend"
_DELETION_CHALLENGE_RATE_LIMIT_PER_MINUTE = 6
_DELETION_PROOF_RATE_LIMIT_PER_HOUR = 6

# A fixed, non-configurable cadence keeps production cleanup inside the policy's
# five-minute maintenance allowance. The only Fly Machine is pinned running so
# this loop is not suspended by idle auto-stop.
AUTH_MAINTENANCE_INTERVAL_SECONDS = 60

# Security-event fields are a closed operational vocabulary. Some callers pass
# store conflict codes or composed quota scopes, so bounding only the format
# string would still allow an accidental request value to reach the logs.
_SECURITY_EVENT_NAMES = frozenset(
    {
        "assertion_rejected",
        "assertion_succeeded",
        "auth_maintenance_failed",
        "bridge_bearer_accepted",
        "bridge_bearer_rejected",
        "deletion_rejected",
        "installation_deleted",
        "installation_rejected",
        "rate_limit_exceeded",
        "registration_rejected",
        "registration_succeeded",
    }
)
_SECURITY_EVENT_CODES = frozenset(
    {
        "-",
        "app_attest_key_already_registered",
        "assertion_counter_replay",
        "bridge_expired",
        "challenge_already_used",
        "challenge_mismatch",
        "configuration_mismatch",
        "deletion_maintenance_pending",
        "expired_challenge",
        "invalid_app_attest_assertion",
        "invalid_app_attestation",
        "rate_limit_exceeded",
        "revoked_app_attest_key",
        "store_maintenance_failed",
        "unknown_app_attest_key",
        "unknown_challenge",
    }
)
_SECURITY_EVENT_SCOPES = frozenset(
    {
        "-",
        "challenge",
        "challenge-global",
        "deletion-challenge-global",
        "deletion-challenge-ip",
        "deletion-key",
        "deletion-proof-global",
        "deletion-proof-ip",
        "recommend-global",
        "recommend-installation",
        "recommend-ip",
        "registration",
        "registration-global",
        "session-global",
        "session-ip",
        "session-key",
    }
)
_SECURITY_EVENT_PATHS = frozenset({"-", "/recommend"})
_SECURITY_EVENT_MECHANISMS = frozenset({"-", "app_attest", "legacy"})
_SECURITY_EVENT_LEVELS = frozenset({logging.INFO, logging.WARNING, logging.ERROR})


class AuthFlowError(RuntimeError):
    def __init__(
        self,
        *,
        status_code: int,
        code: str,
        message: str,
        retry_after: int | None = None,
    ) -> None:
        super().__init__(code)
        self.status_code = status_code
        self.code = code
        self.message = message
        self.retry_after = retry_after


@dataclass(frozen=True)
class Challenge:
    challenge_id: str
    challenge: str
    expires_at: datetime


@dataclass(frozen=True)
class AppSession:
    access_token: str
    expires_in: int
    expires_at: datetime
    installation_id: str


@dataclass(frozen=True)
class BackendIdentity:
    installation_id: str
    mechanism: Literal["app_attest", "legacy"]


class AppAttestAuthService:
    def __init__(
        self,
        *,
        configuration: AuthConfiguration,
        legacy_device_token: str,
        now: Callable[[], datetime] | None = None,
        verifier: AppAttestVerifier | None = None,
    ) -> None:
        self.configuration = configuration
        self.legacy_device_token = legacy_device_token
        self._now = now or (lambda: datetime.now(UTC))
        self.store: AuthStore | None = None
        self.verifier: AppAttestVerifier | None = None
        self._maintenance_task: asyncio.Task[None] | None = None
        if configuration.app_attest_enabled:
            if configuration.database_path is None:
                raise RuntimeError("Validated App Attest configuration had no database path.")
            self.store = AuthStore(configuration.database_path)
            self.verifier = verifier or AppAttestVerifier(
                app_id=configuration.app_id,
                environment=configuration.app_attest_environment,
                allowed_validation_categories=configuration.allowed_validation_categories,
                allowed_bundle_versions=configuration.allowed_bundle_versions,
            )

    def initialize(self) -> None:
        if self.store is not None:
            self.store.initialize()
            # Apply one cadence of lookahead at cold start; otherwise a row
            # due seconds after startup could exceed its maximum before the
            # first periodic tick.
            self.store.cleanup(
                now=self._timestamp(),
                deadline_lookahead_seconds=AUTH_MAINTENANCE_INTERVAL_SECONDS,
            )

    def start_maintenance(
        self,
        *,
        wait: Callable[[float], Awaitable[None]] = asyncio.sleep,
    ) -> None:
        if self.store is None:
            return
        if self._maintenance_task is not None and not self._maintenance_task.done():
            return
        self._maintenance_task = asyncio.create_task(
            self.run_maintenance_loop(wait=wait),
            name="app-attest-retention-maintenance",
        )

    async def stop_maintenance(self) -> None:
        task = self._maintenance_task
        self._maintenance_task = None
        if task is None:
            return
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass

    async def run_maintenance_loop(
        self,
        *,
        wait: Callable[[float], Awaitable[None]] = asyncio.sleep,
    ) -> None:
        if self.store is None:
            return
        while True:
            await wait(AUTH_MAINTENANCE_INTERVAL_SECONDS)
            try:
                cleanup_task = asyncio.create_task(
                    asyncio.to_thread(
                        self.store.cleanup,
                        now=self._timestamp(),
                        deadline_lookahead_seconds=AUTH_MAINTENANCE_INTERVAL_SECONDS,
                    )
                )
                try:
                    await asyncio.shield(cleanup_task)
                except asyncio.CancelledError:
                    # Cancellation cannot stop work already executing in a
                    # thread. Wait for the checkpoint before completing app
                    # shutdown, then preserve cancellation for the loop.
                    try:
                        await cleanup_task
                    finally:
                        raise
            except Exception:
                # Maintenance retries on the next fixed tick. Keep the event
                # bounded: exception messages and database identifiers must
                # never enter logs.
                _security_event(
                    event="auth_maintenance_failed",
                    code="store_maintenance_failed",
                    mechanism="app_attest",
                    level=logging.ERROR,
                )

    def issue_challenge(
        self,
        *,
        purpose: ChallengePurpose,
        key_id: str | None,
        client_ip: str,
    ) -> Challenge:
        store = self._required_store()
        now = self._timestamp()
        if purpose != "deletion":
            self._consume_global_rate(
                scope="challenge",
                per_subject_limit=self.configuration.challenge_rate_limit_per_minute,
                window_seconds=60,
                now=now,
            )
            self._consume_rate(
                scope="challenge",
                subject=client_ip,
                limit=self.configuration.challenge_rate_limit_per_minute,
                window_seconds=60,
                now=now,
            )
        challenge_policy: InstallationWritePolicy | None = None
        if purpose == "attestation":
            if key_id is not None:
                raise _bad_request(
                    "unexpected_key_id",
                    "key_id must be omitted for an attestation challenge.",
                )
        else:
            if key_id is None:
                raise _bad_request(
                    "missing_key_id",
                    f"key_id is required for a {purpose} challenge.",
                )
            _decode_key_id(key_id)
            if purpose == "deletion":
                # Shape arbitrary but well-formed key-id probes per source
                # before reading installation state. The aggregate deletion
                # budget is still charged only after a real row is found.
                self._consume_rate(
                    scope="deletion-challenge-ip",
                    subject=client_ip,
                    limit=_DELETION_CHALLENGE_RATE_LIMIT_PER_MINUTE,
                    window_seconds=60,
                    now=now,
                    reserved_deletion_bucket=True,
                )
            installation = store.installation_for_key(key_id)
            if purpose == "deletion":
                scoped_installation = self._require_deletable_installation(installation)
            else:
                scoped_installation = self._require_active_installation(installation)
            challenge_policy = self._installation_write_policy(
                scoped_installation,
                allow_revoked=purpose == "deletion",
            )

        if purpose == "deletion":
            # Unknown random key ids cannot consume aggregate capacity
            # reserved for an installed client that needs to delete its
            # security metadata.
            self._consume_global_rate(
                scope="deletion-challenge",
                per_subject_limit=_DELETION_CHALLENGE_RATE_LIMIT_PER_MINUTE,
                window_seconds=60,
                now=now,
            )

        raw_challenge = secrets.token_bytes(32)
        challenge_id = str(uuid.uuid4())
        expires_at = now + self.configuration.challenge_ttl_seconds
        try:
            store.issue_challenge(
                challenge_id=challenge_id,
                secret=raw_challenge,
                purpose=purpose,
                key_id=key_id,
                expires_at=expires_at,
                now=now,
                policy=challenge_policy,
            )
        except StoreConflictError as exc:
            self._raise_installation_conflict(exc, deletion=purpose == "deletion")
        return Challenge(
            challenge_id=challenge_id,
            challenge=_urlsafe_encode(raw_challenge),
            expires_at=datetime.fromtimestamp(expires_at, UTC),
        )

    def register(
        self,
        *,
        challenge_id: str,
        key_id: str,
        attestation_object: str,
        client_ip: str,
    ) -> AppSession:
        store = self._required_store()
        verifier = self._required_verifier()
        now = self._timestamp()
        self._consume_global_rate(
            scope="registration",
            per_subject_limit=self.configuration.registration_rate_limit_per_hour,
            window_seconds=3600,
            now=now,
        )
        self._consume_rate(
            scope="registration",
            subject=client_ip,
            limit=self.configuration.registration_rate_limit_per_hour,
            window_seconds=3600,
            now=now,
        )
        key_id_bytes = _decode_key_id(key_id)
        attestation_bytes = _standard_base64_decode(
            attestation_object,
            field="attestation_object",
            maximum_bytes=65536,
        )
        payload_hash = hashlib.sha256(
            b"attestation\x00"
            + challenge_id.encode("ascii", errors="strict")
            + b"\x00"
            + key_id.encode("ascii", errors="strict")
            + b"\x00"
            + attestation_bytes
        ).digest()
        try:
            claim = store.claim_challenge(
                challenge_id=challenge_id,
                purpose="attestation",
                key_id=None,
                payload_hash=payload_hash,
                now=now,
            )
        except StoreConflictError as exc:
            if store.installation_for_key(key_id) is not None:
                _security_event(
                    event="registration_rejected",
                    code="app_attest_key_already_registered",
                    mechanism="app_attest",
                    level=logging.WARNING,
                )
                raise AuthFlowError(
                    status_code=409,
                    code="app_attest_key_already_registered",
                    message="This App Attest key is already registered.",
                ) from exc
            _security_event(
                event="registration_rejected",
                code=exc.code,
                mechanism="app_attest",
                level=logging.WARNING,
            )
            raise _challenge_error(exc.code) from exc

        if store.installation_for_key(key_id) is not None:
            store.fail_challenge(challenge_id)
            _security_event(
                event="registration_rejected",
                code="app_attest_key_already_registered",
                mechanism="app_attest",
                level=logging.WARNING,
            )
            raise AuthFlowError(
                status_code=409,
                code="app_attest_key_already_registered",
                message="This App Attest key is already registered.",
            )
        try:
            result = verifier.verify_attestation(
                attestation_object=attestation_bytes,
                key_id=key_id_bytes,
                challenge=claim.challenge.secret,
                now=self._now(),
            )
        except (
            AppAttestValidationError,
            ValueError,
            x509.ExtensionNotFound,
            UnsupportedAlgorithm,
        ) as exc:
            store.fail_challenge(challenge_id)
            _security_event(
                event="registration_rejected",
                code="invalid_app_attestation",
                mechanism="app_attest",
                level=logging.WARNING,
            )
            raise AuthFlowError(
                status_code=401,
                code="invalid_app_attestation",
                message="The app installation could not be verified.",
            ) from exc

        installation_id = str(uuid.uuid4())
        session, token = self._new_session(installation_id=installation_id, now=now)
        try:
            store.complete_registration(
                challenge_id=challenge_id,
                installation_id=installation_id,
                key_id=key_id,
                public_key_der=result.public_key_der,
                opaque_receipt=result.opaque_receipt,
                app_id=self.configuration.app_id,
                attest_environment=self.configuration.app_attest_environment,
                validation_category=result.validation_category,
                bundle_version=result.bundle_version,
                session_id=session.session_id,
                token_hash=hashlib.sha256(token.encode("ascii")).digest(),
                session_expires_at=session.expires_at,
                now=now,
            )
        except StoreConflictError as exc:
            store.fail_challenge(challenge_id)
            code = (
                "app_attest_key_already_registered"
                if exc.code == "app_attest_key_already_registered"
                else exc.code
            )
            _security_event(
                event="registration_rejected",
                code=code,
                mechanism="app_attest",
                level=logging.WARNING,
            )
            raise AuthFlowError(
                status_code=409,
                code=code,
                message="The enrollment request was already used.",
            ) from exc
        _security_event(
            event="registration_succeeded",
            mechanism="app_attest",
        )
        return self._session_response(session, token)

    def create_session(
        self,
        *,
        challenge_id: str,
        key_id: str,
        assertion_object: str,
        client_data: str,
        client_ip: str,
    ) -> AppSession:
        store = self._required_store()
        verifier = self._required_verifier()
        now = self._timestamp()
        self._consume_global_rate(
            scope="session",
            per_subject_limit=self.configuration.session_rate_limit_per_hour,
            window_seconds=3600,
            now=now,
        )
        _decode_key_id(key_id)
        self._consume_rate(
            scope="session-ip",
            subject=client_ip,
            limit=self.configuration.session_rate_limit_per_hour,
            window_seconds=3600,
            now=now,
        )
        installation = store.installation_for_key(key_id)
        active_installation = self._require_active_installation(installation)
        installation_policy = self._installation_write_policy(active_installation)
        assertion_bytes = _standard_base64_decode(
            assertion_object,
            field="assertion_object",
            maximum_bytes=8192,
        )
        client_data_bytes = _standard_base64_decode(
            client_data,
            field="client_data",
            maximum_bytes=4096,
        )
        payload_hash = hashlib.sha256(
            b"assertion\x00"
            + challenge_id.encode("ascii", errors="strict")
            + b"\x00"
            + key_id.encode("ascii", errors="strict")
            + b"\x00"
            + assertion_bytes
            + b"\x00"
            + client_data_bytes
        ).digest()
        try:
            claim = store.claim_challenge(
                challenge_id=challenge_id,
                purpose="assertion",
                key_id=key_id,
                payload_hash=payload_hash,
                now=now,
                policy=installation_policy,
            )
        except StoreConflictError as exc:
            _security_event(
                event="assertion_rejected",
                code=exc.code,
                mechanism="app_attest",
                level=logging.WARNING,
            )
            if exc.code in {
                "unknown_app_attest_key",
                "configuration_mismatch",
                "revoked_app_attest_key",
            }:
                self._raise_installation_conflict(exc, deletion=False)
            raise _challenge_error(exc.code) from exc

        if claim.installation is None:
            raise RuntimeError("Key-bound assertion claim had no installation.")
        active_installation = claim.installation
        installation_policy = self._installation_write_policy(active_installation)

        try:
            _validate_assertion_client_data(
                client_data_bytes,
                challenge_id=challenge_id,
                challenge=_urlsafe_encode(claim.challenge.secret),
                key_id=key_id,
            )
            result = verifier.verify_assertion(
                assertion_object=assertion_bytes,
                client_data=client_data_bytes,
                public_key_der=active_installation.public_key_der,
                previous_sign_count=active_installation.sign_count,
            )
        except (AppAttestValidationError, ValueError, UnsupportedAlgorithm) as exc:
            store.fail_challenge(challenge_id)
            _security_event(
                event="assertion_rejected",
                code="invalid_app_attest_assertion",
                mechanism="app_attest",
                level=logging.WARNING,
            )
            raise AuthFlowError(
                status_code=401,
                code="invalid_app_attest_assertion",
                message="The app assertion could not be verified.",
            ) from exc

        # A key identifier is public metadata, not an authentication secret.
        # Charge the per-key quota only after proving private-key possession so
        # an unauthenticated caller cannot starve another installation's
        # session-renewal budget. The IP quota above still bounds bad proofs.
        try:
            self._consume_installation_rate(
                scope="session-key",
                subject=key_id,
                limit=self.configuration.session_rate_limit_per_hour,
                window_seconds=3600,
                now=now,
                key_id=key_id,
                policy=installation_policy,
            )
        except AuthFlowError:
            store.fail_challenge(challenge_id)
            raise

        session, token = self._new_session(
            installation_id=active_installation.installation_id,
            now=now,
        )
        try:
            stored = store.complete_assertion(
                challenge_id=challenge_id,
                key_id=key_id,
                previous_sign_count=active_installation.sign_count,
                new_sign_count=result.sign_count,
                validation_category=result.validation_category,
                bundle_version=result.bundle_version,
                session_id=session.session_id,
                token_hash=hashlib.sha256(token.encode("ascii")).digest(),
                session_expires_at=session.expires_at,
                now=now,
                policy=installation_policy,
            )
        except StoreConflictError as exc:
            store.fail_challenge(challenge_id)
            _security_event(
                event="assertion_rejected",
                code=exc.code,
                mechanism="app_attest",
                level=logging.WARNING,
            )
            if exc.code in {
                "unknown_app_attest_key",
                "configuration_mismatch",
                "revoked_app_attest_key",
            }:
                self._raise_installation_conflict(exc, deletion=False)
            raise AuthFlowError(
                status_code=409,
                code=exc.code,
                message="The assertion was already used.",
            ) from exc
        _security_event(
            event="assertion_succeeded",
            mechanism="app_attest",
        )
        return self._session_response(stored, token)

    def delete_installation(
        self,
        *,
        challenge_id: str,
        key_id: str,
        assertion_object: str,
        client_data: str,
        client_ip: str,
    ) -> None:
        """Delete the installation proven by a fresh one-time assertion."""
        store = self._required_store()
        verifier = self._required_verifier()
        now = self._timestamp()
        _decode_key_id(key_id)
        self._consume_rate(
            scope="deletion-proof-ip",
            subject=client_ip,
            limit=_DELETION_PROOF_RATE_LIMIT_PER_HOUR,
            window_seconds=3600,
            now=now,
            reserved_deletion_bucket=True,
        )
        installation = self._require_deletable_installation(
            store.installation_for_key(key_id)
        )
        installation_policy = self._installation_write_policy(
            installation,
            allow_revoked=True,
        )
        assertion_bytes = _standard_base64_decode(
            assertion_object,
            field="assertion_object",
            maximum_bytes=8192,
        )
        client_data_bytes = _standard_base64_decode(
            client_data,
            field="client_data",
            maximum_bytes=4096,
        )
        payload_hash = hashlib.sha256(
            b"deletion\x00"
            + challenge_id.encode("ascii", errors="strict")
            + b"\x00"
            + key_id.encode("ascii", errors="strict")
            + b"\x00"
            + assertion_bytes
            + b"\x00"
            + client_data_bytes
        ).digest()
        try:
            claim = store.claim_challenge(
                challenge_id=challenge_id,
                purpose="deletion",
                key_id=key_id,
                payload_hash=payload_hash,
                now=now,
                policy=installation_policy,
            )
        except StoreConflictError as exc:
            _security_event(
                event="deletion_rejected",
                code=exc.code,
                mechanism="app_attest",
                level=logging.WARNING,
            )
            if exc.code in {
                "unknown_app_attest_key",
                "configuration_mismatch",
                "revoked_app_attest_key",
            }:
                self._raise_installation_conflict(exc, deletion=True)
            raise _challenge_error(exc.code) from exc

        if claim.installation is None:
            raise RuntimeError("Key-bound deletion claim had no installation.")
        installation = claim.installation
        installation_policy = self._installation_write_policy(
            installation,
            allow_revoked=True,
        )

        try:
            _validate_assertion_client_data(
                client_data_bytes,
                purpose="deletion",
                challenge_id=challenge_id,
                challenge=_urlsafe_encode(claim.challenge.secret),
                key_id=key_id,
            )
            verifier.verify_assertion(
                assertion_object=assertion_bytes,
                client_data=client_data_bytes,
                public_key_der=installation.public_key_der,
                previous_sign_count=installation.sign_count,
            )
        except (AppAttestValidationError, ValueError, UnsupportedAlgorithm) as exc:
            store.fail_challenge(challenge_id)
            _security_event(
                event="deletion_rejected",
                code="invalid_app_attest_assertion",
                mechanism="app_attest",
                level=logging.WARNING,
            )
            raise AuthFlowError(
                status_code=401,
                code="invalid_app_attest_assertion",
                message="The app installation deletion could not be verified.",
            ) from exc

        # Invalid proofs consume only their source-IP budget. Aggregate and
        # key capacity are reserved for a caller that proved current private-
        # key possession, so distributed junk cannot starve valid deletion.
        self._consume_global_rate(
            scope="deletion-proof",
            per_subject_limit=_DELETION_PROOF_RATE_LIMIT_PER_HOUR,
            window_seconds=3600,
            now=now,
        )
        try:
            self._consume_installation_rate(
                scope="deletion-key",
                subject=key_id,
                limit=_DELETION_PROOF_RATE_LIMIT_PER_HOUR,
                window_seconds=3600,
                now=now,
                key_id=key_id,
                policy=installation_policy,
                reserved_deletion_bucket=True,
            )
        except AuthFlowError:
            store.fail_challenge(challenge_id)
            raise

        rate_subject_hashes = (
            ("session-key", self._subject_hash("session-key", key_id)),
            ("deletion-key", self._subject_hash("deletion-key", key_id)),
            (
                "recommend-installation",
                self._subject_hash("recommend-installation", installation.installation_id),
            ),
        )
        try:
            store.complete_installation_deletion(
                challenge_id=challenge_id,
                key_id=key_id,
                installation_id=installation.installation_id,
                previous_sign_count=installation.sign_count,
                rate_subject_hashes=rate_subject_hashes,
                policy=installation_policy,
            )
        except StoreConflictError as exc:
            store.fail_challenge(challenge_id)
            _security_event(
                event="deletion_rejected",
                code=exc.code,
                mechanism="app_attest",
                level=logging.WARNING,
            )
            if exc.code == "unknown_app_attest_key":
                self._raise_installation_conflict(exc, deletion=True)
            if exc.code == "configuration_mismatch":
                self._raise_installation_conflict(exc, deletion=True)
            raise AuthFlowError(
                status_code=409,
                code=exc.code,
                message="The deletion assertion was already used.",
            ) from exc
        except DeletionMaintenancePending as exc:
            _security_event(
                event="deletion_rejected",
                code="deletion_maintenance_pending",
                mechanism="app_attest",
                level=logging.WARNING,
            )
            raise AuthFlowError(
                status_code=503,
                code="deletion_maintenance_pending",
                message="Server deletion maintenance is still completing; try again.",
                retry_after=1,
            ) from exc
        _security_event(
            event="installation_deleted",
            mechanism="app_attest",
        )

    def authenticate_bearer(
        self,
        *,
        token: str,
        path: str,
        client_ip: str,
    ) -> BackendIdentity:
        now_datetime = self._now().astimezone(UTC)
        now = int(now_datetime.timestamp())
        if self.store is not None:
            self._rate_limit_api_global(path=path, now=now)
            # Consume the trusted-IP quota before bearer lookup so missing and
            # invalid credentials cannot bypass endpoint abuse limits. A valid
            # App Attest identity is charged only once at the IP layer, then
            # separately at the installation layer below.
            self._rate_limit_api_ip(path=path, client_ip=client_ip, now=now)
            token_hash = _bearer_token_hash(token)
            try:
                installation = (
                    self.store.authenticate_session(
                        token_hash=token_hash,
                        now=now,
                        policy=self._bearer_write_policy(),
                    )
                    if token_hash is not None
                    else None
                )
            except StoreConflictError as exc:
                self._raise_installation_conflict(exc, deletion=False)
            if installation is not None:
                active_installation = self._require_active_installation(installation)
                identity = BackendIdentity(
                    installation_id=active_installation.installation_id,
                    mechanism="app_attest",
                )
                self._rate_limit_api_installation(
                    installation=active_installation,
                    path=path,
                    now=now,
                )
                return identity

        if self.configuration.legacy_allowed(now=now_datetime):
            if not self.legacy_device_token:
                raise AuthFlowError(
                    status_code=503,
                    code="legacy_auth_not_configured",
                    message="Development authentication is not configured.",
                )
            if _legacy_token_matches(token, self.legacy_device_token):
                _security_event(
                    event="bridge_bearer_accepted",
                    path=_security_path(path),
                    mechanism="legacy",
                    level=logging.WARNING,
                )
                identity = BackendIdentity(
                    installation_id="legacy-development-client",
                    mechanism="legacy",
                )
                return identity

        if (
            self.configuration.mode == "bridge"
            and _legacy_token_matches(token, self.legacy_device_token)
        ):
            _security_event(
                event="bridge_bearer_rejected",
                code="bridge_expired",
                path=_security_path(path),
                mechanism="legacy",
                level=logging.WARNING,
            )

        raise AuthFlowError(
            status_code=401,
            code="invalid_or_expired_session",
            message="The backend session is invalid or expired.",
        )

    def _api_rate_limit(self, path: str) -> tuple[str, int] | None:
        if path == "/recommend":
            return "recommend", self.configuration.recommend_rate_limit_per_hour
        return None

    def _rate_limit_api_ip(
        self,
        *,
        path: str,
        client_ip: str,
        now: int,
    ) -> None:
        rate_limit = self._api_rate_limit(path)
        if rate_limit is None:
            return
        scope, limit = rate_limit
        self._consume_rate(
            scope=f"{scope}-ip",
            subject=client_ip,
            limit=limit,
            window_seconds=3600,
            now=now,
        )

    def _rate_limit_api_global(self, *, path: str, now: int) -> None:
        rate_limit = self._api_rate_limit(path)
        if rate_limit is None:
            return
        scope, limit = rate_limit
        self._consume_global_rate(
            scope=scope,
            per_subject_limit=limit,
            window_seconds=3600,
            now=now,
        )

    def _rate_limit_api_installation(
        self,
        *,
        installation: InstallationRecord,
        path: str,
        now: int,
    ) -> None:
        rate_limit = self._api_rate_limit(path)
        if rate_limit is None:
            return
        scope, limit = rate_limit
        self._consume_installation_rate(
            scope=f"{scope}-installation",
            subject=installation.installation_id,
            limit=limit,
            window_seconds=3600,
            now=now,
            installation_id=installation.installation_id,
            policy=self._installation_write_policy(installation),
        )

    def _consume_rate(
        self,
        *,
        scope: str,
        subject: str,
        limit: int,
        window_seconds: int,
        now: int,
        reserved_global_bucket: bool = False,
        reserved_deletion_bucket: bool = False,
    ) -> None:
        store = self._required_store()
        try:
            store.consume_rate_limit(
                scope=scope,
                subject_hash=self._subject_hash(scope, subject),
                limit=limit,
                window_seconds=window_seconds,
                now=now,
                reserved_global_bucket=reserved_global_bucket,
                reserved_deletion_bucket=reserved_deletion_bucket,
            )
        except RateLimitExceeded as exc:
            _security_event(
                event="rate_limit_exceeded",
                code="rate_limit_exceeded",
                scope=scope,
                level=logging.WARNING,
            )
            raise AuthFlowError(
                status_code=429,
                code="rate_limit_exceeded",
                message="Too many authentication or backend requests.",
                retry_after=exc.retry_after,
            ) from exc

    def _consume_installation_rate(
        self,
        *,
        scope: str,
        subject: str,
        limit: int,
        window_seconds: int,
        now: int,
        policy: InstallationWritePolicy,
        key_id: str | None = None,
        installation_id: str | None = None,
        reserved_deletion_bucket: bool = False,
    ) -> None:
        store = self._required_store()
        try:
            store.consume_installation_rate_limit(
                scope=scope,
                subject_hash=self._subject_hash(scope, subject),
                limit=limit,
                window_seconds=window_seconds,
                now=now,
                key_id=key_id,
                installation_id=installation_id,
                policy=policy,
                reserved_deletion_bucket=reserved_deletion_bucket,
            )
        except RateLimitExceeded as exc:
            _security_event(
                event="rate_limit_exceeded",
                code="rate_limit_exceeded",
                scope=scope,
                level=logging.WARNING,
            )
            raise AuthFlowError(
                status_code=429,
                code="rate_limit_exceeded",
                message="Too many authentication or backend requests.",
                retry_after=exc.retry_after,
            ) from exc
        except StoreConflictError as exc:
            self._raise_installation_conflict(
                exc,
                deletion=policy.allow_revoked,
            )

    def _consume_global_rate(
        self,
        *,
        scope: str,
        per_subject_limit: int,
        window_seconds: int,
        now: int,
    ) -> None:
        self._consume_rate(
            scope=f"{scope}-global",
            subject=_GLOBAL_RATE_SUBJECT,
            limit=per_subject_limit * _GLOBAL_RATE_LIMIT_MULTIPLIER,
            window_seconds=window_seconds,
            now=now,
            reserved_global_bucket=True,
        )

    def _subject_hash(self, scope: str, subject: str) -> str:
        return hmac.new(
            self.configuration.session_secret,
            f"wardrobe-rate-v1\x00{scope}\x00{subject}".encode(),
            hashlib.sha256,
        ).hexdigest()

    def _new_session(self, *, installation_id: str, now: int) -> tuple[SessionRecord, str]:
        token = secrets.token_urlsafe(32)
        session = SessionRecord(
            session_id=str(uuid.uuid4()),
            installation_id=installation_id,
            expires_at=now + self.configuration.session_ttl_seconds,
        )
        return session, token

    def _session_response(self, session: SessionRecord, token: str) -> AppSession:
        return AppSession(
            access_token=token,
            expires_in=max(0, session.expires_at - self._timestamp()),
            expires_at=datetime.fromtimestamp(session.expires_at, UTC),
            installation_id=session.installation_id,
        )

    def _installation_write_policy(
        self,
        installation: InstallationRecord,
        *,
        allow_revoked: bool = False,
    ) -> InstallationWritePolicy:
        return InstallationWritePolicy(
            installation_id=installation.installation_id,
            app_id=self.configuration.app_id,
            attest_environment=self.configuration.app_attest_environment,
            allow_revoked=allow_revoked,
        )

    def _bearer_write_policy(self) -> InstallationWritePolicy:
        return InstallationWritePolicy(
            installation_id=None,
            app_id=self.configuration.app_id,
            attest_environment=self.configuration.app_attest_environment,
        )

    def _raise_installation_conflict(
        self,
        error: StoreConflictError,
        *,
        deletion: bool,
    ) -> NoReturn:
        if error.code == "unknown_app_attest_key":
            if deletion:
                # Preserve the deletion endpoint's idempotent privacy
                # guarantee even when another request removed the row between
                # the service's read and the scoped-write transaction.
                self._require_deletable_installation(None)
            self._require_active_installation(None)
        if error.code == "configuration_mismatch":
            _security_event(
                event="deletion_rejected" if deletion else "installation_rejected",
                code="configuration_mismatch",
                mechanism="app_attest",
                level=logging.WARNING,
            )
            if deletion:
                raise AuthFlowError(
                    status_code=401,
                    code="configuration_mismatch",
                    message="The App Attest key does not belong to this service configuration.",
                ) from error
            raise AuthFlowError(
                status_code=401,
                code="unknown_app_attest_key",
                message="The App Attest key is unknown; enroll this installation again.",
            ) from error
        if error.code == "revoked_app_attest_key":
            _security_event(
                event="installation_rejected",
                code="revoked_app_attest_key",
                mechanism="app_attest",
                level=logging.WARNING,
            )
            raise AuthFlowError(
                status_code=401,
                code="revoked_app_attest_key",
                message="The App Attest key was revoked; enroll a new installation.",
            ) from error
        raise error

    def _require_active_installation(
        self,
        installation: InstallationRecord | None,
    ) -> InstallationRecord:
        if installation is None:
            _security_event(
                event="installation_rejected",
                code="unknown_app_attest_key",
                mechanism="app_attest",
                level=logging.WARNING,
            )
            raise AuthFlowError(
                status_code=401,
                code="unknown_app_attest_key",
                message="The App Attest key is unknown; enroll this installation again.",
            )
        if installation.revoked_at is not None:
            _security_event(
                event="installation_rejected",
                code="revoked_app_attest_key",
                mechanism="app_attest",
                level=logging.WARNING,
            )
            raise AuthFlowError(
                status_code=401,
                code="revoked_app_attest_key",
                message="The App Attest key was revoked; enroll a new installation.",
            )
        if (
            installation.app_id != self.configuration.app_id
            or installation.attest_environment
            != self.configuration.app_attest_environment
        ):
            # Treat restored state from another App ID or App Attest
            # environment as unknown so the client discards its stale key and
            # generates a fresh one. Assertions contain no AAGUID with which to
            # repair a mismatched persisted row.
            _security_event(
                event="installation_rejected",
                code="configuration_mismatch",
                mechanism="app_attest",
                level=logging.WARNING,
            )
            raise AuthFlowError(
                status_code=401,
                code="unknown_app_attest_key",
                message="The App Attest key is unknown; enroll this installation again.",
            )
        return installation

    def _require_deletable_installation(
        self,
        installation: InstallationRecord | None,
    ) -> InstallationRecord:
        if installation is None:
            try:
                # A previous deletion may have committed before its WAL
                # checkpoint could complete. Do not let an idempotent retry
                # report success until the active database maintenance is
                # complete as required by the lifecycle policy.
                self._required_store().checkpoint_and_truncate_wal()
            except Exception as exc:
                _security_event(
                    event="deletion_rejected",
                    code="deletion_maintenance_pending",
                    mechanism="app_attest",
                    level=logging.WARNING,
                )
                raise AuthFlowError(
                    status_code=503,
                    code="deletion_maintenance_pending",
                    message="Server deletion maintenance is still completing; try again.",
                    retry_after=1,
                ) from exc
            _security_event(
                event="deletion_rejected",
                code="unknown_app_attest_key",
                mechanism="app_attest",
                level=logging.WARNING,
            )
            raise AuthFlowError(
                status_code=401,
                code="unknown_app_attest_key",
                message="The App Attest key is unknown; the server identity is absent.",
            )
        if (
            installation.app_id != self.configuration.app_id
            or installation.attest_environment
            != self.configuration.app_attest_environment
        ):
            _security_event(
                event="deletion_rejected",
                code="configuration_mismatch",
                mechanism="app_attest",
                level=logging.WARNING,
            )
            raise AuthFlowError(
                status_code=401,
                code="configuration_mismatch",
                message="The App Attest key does not belong to this service configuration.",
            )
        # A revoked installation may still prove possession solely to remove
        # its retained server metadata. It remains forbidden for sessions.
        return installation

    def _required_store(self) -> AuthStore:
        if self.store is None:
            raise AuthFlowError(
                status_code=404,
                code="app_attest_not_enabled",
                message="App Attest authentication is not enabled on this backend.",
            )
        return self.store

    def _required_verifier(self) -> AppAttestVerifier:
        if self.verifier is None:
            raise RuntimeError("App Attest verifier was not initialized.")
        return self.verifier

    def _timestamp(self) -> int:
        return int(self._now().astimezone(UTC).timestamp())


def _validate_assertion_client_data(
    data: bytes,
    *,
    purpose: Literal["assertion", "deletion"] = "assertion",
    challenge_id: str,
    challenge: str,
    key_id: str,
) -> None:
    def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for name, value in pairs:
            if name in result:
                raise ValueError("Duplicate JSON field.")
            result[name] = value
        return result

    try:
        decoded = json.loads(data.decode("utf-8"), object_pairs_hook=unique_object)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError("Invalid assertion client data.") from exc
    expected = {
        "version": 1,
        "purpose": purpose,
        "challenge_id": challenge_id,
        "challenge": challenge,
        "key_id": key_id,
    }
    if not isinstance(decoded, dict) or set(decoded) != set(expected):
        raise ValueError("Invalid assertion client data fields.")
    if type(decoded["version"]) is not int or decoded != expected:
        raise ValueError("Assertion client data did not match the challenge.")
    canonical = json.dumps(
        expected,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")
    if not hmac.compare_digest(data, canonical):
        raise ValueError("Assertion client data was not canonical.")


def _decode_key_id(value: str) -> bytes:
    decoded = _standard_base64_decode(value, field="key_id", maximum_bytes=32)
    if len(decoded) != 32:
        raise _bad_request("invalid_key_id", "key_id must decode to exactly 32 bytes.")
    if base64.b64encode(decoded).decode("ascii") != value:
        raise _bad_request("invalid_key_id", "key_id must use canonical standard Base64.")
    return decoded


def _standard_base64_decode(value: str, *, field: str, maximum_bytes: int) -> bytes:
    if not value or len(value) > ((maximum_bytes + 2) // 3 * 4) + 4:
        raise _bad_request("invalid_base64", f"{field} is missing or too large.")
    try:
        decoded = base64.b64decode(value, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise _bad_request("invalid_base64", f"{field} must use standard Base64.") from exc
    if not decoded or len(decoded) > maximum_bytes:
        raise _bad_request("invalid_base64", f"{field} is missing or too large.")
    return decoded


def _urlsafe_encode(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).decode("ascii").rstrip("=")


def _bearer_token_hash(value: str) -> bytes | None:
    try:
        encoded = value.encode("utf-8")
    except UnicodeEncodeError:
        return None
    return hashlib.sha256(encoded).digest()


def _legacy_token_matches(candidate: str, expected: str) -> bool:
    candidate_hash = _bearer_token_hash(candidate)
    expected_hash = _bearer_token_hash(expected)
    return (
        candidate_hash is not None
        and expected_hash is not None
        and secrets.compare_digest(candidate_hash, expected_hash)
    )


def _security_path(path: str) -> str:
    return path if path == "/recommend" else "-"


def _security_event(
    *,
    event: str,
    code: str = "-",
    scope: str = "-",
    path: str = "-",
    mechanism: str = "-",
    level: int = logging.INFO,
) -> None:
    # Keep this defense at the final log boundary: callers that accidentally
    # forward a store code, route, or quota scope outside the reviewed
    # vocabulary are redacted instead of becoming an unbounded log field.
    event = _bounded_security_value(event, _SECURITY_EVENT_NAMES)
    code = _bounded_security_value(code, _SECURITY_EVENT_CODES)
    scope = _bounded_security_value(scope, _SECURITY_EVENT_SCOPES)
    path = _bounded_security_value(path, _SECURITY_EVENT_PATHS)
    mechanism = _bounded_security_value(mechanism, _SECURITY_EVENT_MECHANISMS)
    level = level if level in _SECURITY_EVENT_LEVELS else logging.WARNING
    logger.log(
        level,
        "auth_security_event event=%s code=%s scope=%s path=%s mechanism=%s",
        event,
        code,
        scope,
        path,
        mechanism,
    )


def _bounded_security_value(value: str, allowed: frozenset[str]) -> str:
    return value if isinstance(value, str) and value in allowed else "-"


def _bad_request(code: str, message: str) -> AuthFlowError:
    return AuthFlowError(status_code=400, code=code, message=message)


def _challenge_error(code: str) -> AuthFlowError:
    messages = {
        "unknown_challenge": "The challenge is unknown.",
        "expired_challenge": "The challenge expired.",
        "challenge_mismatch": "The challenge does not match this operation.",
        "challenge_already_used": "The challenge was already used.",
    }
    return AuthFlowError(
        status_code=409,
        code=code,
        message=messages.get(code, "The challenge cannot be used."),
    )
