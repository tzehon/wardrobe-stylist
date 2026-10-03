"""Inactive signed-evidence inspection, NOT ownership or entitlement authorization.

Apple's SDK owns ES256, certificate-chain and online revocation verification.
Configured roots must be reviewed Apple roots, supplied by trusted deployment
code, never a request. No live caller, roots, product configuration or route is
installed. Evidence remains volatile and cannot activate CommerceStore by itself.
"""

from __future__ import annotations

import base64
import binascii
import json
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from typing import cast
from uuid import UUID

from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier

from app.schemas.commerce import MAX_TIMESTAMP

MAX_JWS_BYTES = 32768
MAX_TIME_MS = MAX_TIMESTAMP * 1000 + 999


class AppleEvidenceError(ValueError):
    """Fixed codes only; do not expose receipts, identity or upstream errors."""


def _text(value: object) -> str:
    if not isinstance(value, str) or not 1 <= len(value) <= 128 or not value.isascii():
        raise AppleEvidenceError("invalid_claim")
    if any(ord(char) < 33 or ord(char) > 126 for char in value):
        raise AppleEvidenceError("invalid_claim")
    return value


def _integer(value: object, maximum: int = MAX_TIME_MS) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or not 0 <= value <= maximum:
        raise AppleEvidenceError("invalid_claim")
    return value


def _unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise AppleEvidenceError("invalid_jws")
        result[key] = value
    return result


def _invalid_constant(value: str) -> object:
    raise AppleEvidenceError("invalid_jws")


def _json_segment(segment: str) -> dict[str, object]:
    try:
        # Reject permissive base64 and duplicate JSON keys before the SDK sees
        # them. These are shape checks only; nothing is trusted before verify.
        data = base64.b64decode(segment + "=" * (-len(segment) % 4), altchars=b"-_", validate=True)
        decoded: object = json.loads(
            data, object_pairs_hook=_unique_object, parse_constant=_invalid_constant,
        )
        if not isinstance(decoded, dict):
            raise AppleEvidenceError("invalid_jws")
        return cast(dict[str, object], decoded)
    except (ValueError, binascii.Error, RecursionError):
        raise AppleEvidenceError("invalid_jws") from None


@dataclass(frozen=True)
class AppleEvidencePolicy:
    environment: Environment
    bundle_id: str
    app_apple_id: int
    product_id: str
    subscription_group: str
    # A deliberately explicit policy input, not an approved production default.
    max_signed_age_ms: int
    future_skew_ms: int = 60_000

    def __post_init__(self) -> None:
        if (not isinstance(self.environment, Environment)
                or self.environment not in (Environment.PRODUCTION, Environment.SANDBOX)):
            raise AppleEvidenceError("invalid_environment")
        for value in (self.bundle_id, self.product_id, self.subscription_group):
            _text(value)
        if _integer(self.app_apple_id) == 0:
            raise AppleEvidenceError("invalid_policy")
        if not 1 <= _integer(self.max_signed_age_ms) <= 86_400_000:
            raise AppleEvidenceError("invalid_policy")
        if _integer(self.future_skew_ms) > 300_000:
            raise AppleEvidenceError("invalid_policy")


@dataclass(frozen=True, repr=False)
class AppEvidence:
    app_transaction_id: str
    signed_at_ms: int
    # Signed opaque claims, NOT a validated device-proof result. Exact proof
    # computation is documented but not implemented or bound to an installation.
    device_verification: bytes = field(repr=False)
    device_verification_nonce: str = field(repr=False)


@dataclass(frozen=True, repr=False)
class PurchaseEvidence:
    app_transaction_id: str
    transaction_id: str
    original_transaction_id: str
    purchase_at_ms: int
    expires_at_ms: int
    signed_at_ms: int


@dataclass(frozen=True, repr=False)
class SignedEvidencePair:
    """Consistent signed claims, never an owner binding or current entitlement."""

    app: AppEvidence
    purchase: PurchaseEvidence


class AppleEvidenceVerifier:
    def __init__(
        self, policy: AppleEvidencePolicy, *, root_certificates: tuple[bytes, ...],
        clock_ms: Callable[[], int] | None = None,
    ) -> None:
        if (type(root_certificates) is not tuple or not 1 <= len(root_certificates) <= 4
                or any(type(root) is not bytes or not 1 <= len(root) <= 16384
                       for root in root_certificates)):
            raise AppleEvidenceError("invalid_trust_configuration")
        self.policy = policy
        self.clock_ms = clock_ms or (lambda: time.time_ns() // 1_000_000)
        # Xcode/local-testing signature bypass is prohibited by policy, and
        # there is no public switch to disable online revocation checks.
        self._sdk = SignedDataVerifier(
            root_certificates=list(root_certificates), enable_online_checks=True,
            environment=policy.environment, bundle_id=policy.bundle_id,
            app_apple_id=policy.app_apple_id,
        )

    def _verified_claims(self, signed: str, *, app: bool) -> dict[str, object]:
        if type(signed) is not str or not signed.isascii() or not 1 <= len(signed) <= MAX_JWS_BYTES:
            raise AppleEvidenceError("invalid_jws")
        segments = signed.split(".")
        if len(segments) != 3 or not all(segments):
            raise AppleEvidenceError("invalid_jws")
        header = _json_segment(segments[0])
        claims = _json_segment(segments[1])
        if header.get("alg") != "ES256":
            raise AppleEvidenceError("invalid_jws")
        try:
            if app:
                self._sdk.verify_and_decode_app_transaction(signed)
            else:
                self._sdk.verify_and_decode_signed_transaction(signed)
        except Exception:
            # SDK model conversion can fail outside VerificationException.
            # Fail closed without leaking signed input through chained errors.
            raise AppleEvidenceError("verification_failed") from None
        # Use authenticated RAW claims for policy checks: the SDK's model
        # converter may coerce strings, floats or booleans to numeric fields.
        if claims.get("bundleId") != self.policy.bundle_id:
            raise AppleEvidenceError("identity_mismatch")
        key = "receiptType" if app else "environment"
        if claims.get(key) != self.policy.environment.value:
            raise AppleEvidenceError("environment_mismatch")
        return claims

    def _fresh(self, value: object, now: int) -> int:
        signed_at = _integer(value)
        if (signed_at > now + self.policy.future_skew_ms
                or signed_at < now - self.policy.max_signed_age_ms):
            raise AppleEvidenceError("evidence_not_fresh")
        return signed_at

    def verify_pair(self, app_jws: str, purchase_jws: str) -> SignedEvidencePair:
        """Authenticate matching standard-purchase evidence, without persisting it.

        Expired purchases remain evidence, not access. Refunds, offers, upgrades,
        and nonstandard billing require the future lifecycle reconciler and are
        rejected here. The caller must NOT translate any result directly into a
        grant: freshness is not current-status reconciliation or device ownership.
        """
        started = _integer(self.clock_ms())
        app_claims = self._verified_claims(app_jws, app=True)
        purchase = self._verified_claims(purchase_jws, app=False)
        # Network verification may take time; assess freshness at completion.
        now = _integer(self.clock_ms())
        if now < started:
            raise AppleEvidenceError("invalid_clock")
        if _integer(app_claims.get("appAppleId")) != self.policy.app_apple_id:
            raise AppleEvidenceError("identity_mismatch")
        app_id = _text(app_claims.get("appTransactionId"))
        if _text(purchase.get("appTransactionId")) != app_id:
            raise AppleEvidenceError("transaction_mismatch")
        if (purchase.get("productId") != self.policy.product_id
                or purchase.get("subscriptionGroupIdentifier") != self.policy.subscription_group
                or purchase.get("type") != "Auto-Renewable Subscription"
                or purchase.get("inAppOwnershipType") != "PURCHASED"):
            raise AppleEvidenceError("unsupported_purchase")
        if _integer(purchase.get("quantity"), 1) != 1:
            raise AppleEvidenceError("unsupported_purchase")
        # Apple omits this claim for ordinary purchases; a present value must
        # still be exactly false, never a coerced false-like value or null.
        if "isUpgraded" in purchase and purchase["isUpgraded"] is not False:
            raise AppleEvidenceError("unsupported_purchase")
        unsupported = (
            "offerType", "offerIdentifier", "offerDiscountType", "offerPeriod",
            "revocationDate", "revocationReason", "revocationType", "revocationPercentage",
            "advancedCommerceInfo", "billingPlanType", "commitmentInfo",
        )
        if any(purchase.get(key) is not None for key in unsupported):
            raise AppleEvidenceError("reconciliation_required")
        if purchase.get("price") is not None and _integer(purchase["price"]) == 0:
            raise AppleEvidenceError("unsupported_purchase")
        app_signed = self._fresh(app_claims.get("receiptCreationDate"), now)
        signed_at = self._fresh(purchase.get("signedDate"), now)
        start, end = _integer(purchase.get("purchaseDate")), _integer(purchase.get("expiresDate"))
        original = _integer(purchase.get("originalPurchaseDate"))
        if not original <= start < end or start > signed_at:
            raise AppleEvidenceError("invalid_period")
        try:
            nonce = _text(app_claims.get("deviceVerificationNonce"))
            UUID(nonce)
            encoded = app_claims.get("deviceVerification")
            if not isinstance(encoded, str) or not 1 <= len(encoded) <= 1024:
                raise ValueError
            device = base64.b64decode(encoded, validate=True)
            if not 1 <= len(device) <= 512:
                raise ValueError
        except (ValueError, binascii.Error):
            raise AppleEvidenceError("invalid_device_claims") from None
        return SignedEvidencePair(
            AppEvidence(app_id, app_signed, device, nonce),
            PurchaseEvidence(app_id, _text(purchase.get("transactionId")),
                             _text(purchase.get("originalTransactionId")), start, end, signed_at),
        )
