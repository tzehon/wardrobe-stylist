"""Real ES256/chain verification with ephemeral synthetic certificates, NOT Apple fixtures.

Only OCSP is stubbed; these tests prove the adapter boundary, not device ownership
or compatibility with live Apple data. No private key or receipt is retained.
"""

import base64
import json
import time
from dataclasses import replace
from datetime import UTC, datetime, timedelta
from unittest.mock import Mock

import jwt
import pytest
from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.signed_data_verifier import _ChainVerifier
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec

from app.commerce.apple_evidence import (
    AppleEvidenceError,
    AppleEvidencePolicy,
    AppleEvidenceVerifier,
)


@pytest.fixture
def chain():
    now = datetime.now(UTC)
    keys = [ec.generate_private_key(ec.SECP256R1()) for _ in range(3)]
    names = [x509.Name([x509.NameAttribute(x509.NameOID.COMMON_NAME, f"Synthetic {i}")])
             for i in range(3)]
    certificates = []
    for index, key in enumerate(keys):
        issuer = max(0, index - 1)
        ca = index < 2
        builder = (x509.CertificateBuilder().subject_name(names[index])
                   .issuer_name(names[issuer]).public_key(key.public_key())
                   .serial_number(x509.random_serial_number())
                   .not_valid_before(now - timedelta(days=1))
                   .not_valid_after(now + timedelta(days=1))
                   .add_extension(x509.BasicConstraints(ca, 1 - index if ca else None), True)
                   .add_extension(x509.KeyUsage(True, False, False, False, False,
                                                ca, ca, None, None), True)
                   .add_extension(x509.SubjectKeyIdentifier.from_public_key(
                       key.public_key()), False)
                   .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(
                       keys[issuer].public_key()), False))
        if index:
            oid = "1.2.840.113635.100.6.2.1" if index == 1 else "1.2.840.113635.100.6.11.1"
            builder = builder.add_extension(
                x509.UnrecognizedExtension(x509.ObjectIdentifier(oid), b"\x05\x00"), False)
        certificates.append(builder.sign(keys[issuer], hashes.SHA256()))
    der = [cert.public_bytes(serialization.Encoding.DER) for cert in certificates]
    return keys[-1], der[0], [base64.b64encode(cert).decode() for cert in reversed(der)]


@pytest.fixture
def evidence(chain, monkeypatch):
    key, root, certificates = chain
    now = time.time_ns() // 1_000_000
    policy = AppleEvidencePolicy(Environment.PRODUCTION, "com.example.wardrobe", 123456,
                                 "plus.monthly", "group-1", 300_000)
    ocsp = Mock()
    monkeypatch.setattr(_ChainVerifier, "check_ocsp_status", ocsp)
    verifier = AppleEvidenceVerifier(policy, root_certificates=(root,), clock_ms=lambda: now)
    app = {"bundleId": policy.bundle_id, "appAppleId": policy.app_apple_id,
           "receiptType": "Production", "appTransactionId": "app-1",
           "receiptCreationDate": now,
           "deviceVerification": base64.b64encode(b"opaque-device-evidence" * 2).decode(),
           "deviceVerificationNonce": "d10436b4-03a9-4c83-9d98-5eea0c4a317b"}
    purchase = {"bundleId": policy.bundle_id, "environment": "Production",
                "appTransactionId": "app-1", "productId": policy.product_id,
                "subscriptionGroupIdentifier": policy.subscription_group,
                "type": "Auto-Renewable Subscription", "inAppOwnershipType": "PURCHASED",
                "transactionId": "txn-1",
                "originalTransactionId": "original-1", "purchaseDate": now - 1000,
                "originalPurchaseDate": now - 2000, "expiresDate": now + 86_400_000,
                "signedDate": now}

    def sign(claims):
        return jwt.encode(claims, key, algorithm="ES256", headers={"x5c": certificates})

    return verifier, app, purchase, sign, ocsp, now


@pytest.mark.parametrize("explicit_false", [False, True], ids=["omitted-upgrade", "false-upgrade"])
@pytest.mark.parametrize(
    "explicit_quantity", [False, True], ids=["omitted-quantity", "one-quantity"],
)
def test_real_signature_chain_and_volatile_evidence(evidence, explicit_false, explicit_quantity):
    verifier, app, purchase, sign, ocsp, _ = evidence
    assert "isUpgraded" not in purchase
    if explicit_false:
        purchase["isUpgraded"] = False
    assert "quantity" not in purchase
    if explicit_quantity:
        purchase["quantity"] = 1
    pair = verifier.verify_pair(sign(app), sign(purchase))
    assert pair.app.app_transaction_id == pair.purchase.app_transaction_id == "app-1"
    assert pair.purchase.transaction_id == "txn-1"
    assert pair.app.device_verification == b"opaque-device-evidence" * 2
    assert ocsp.call_count == 2  # SDK reuses the online-checked chain for the second JWS.
    assert verifier._sdk._enable_online_checks is True
    assert "txn-1" not in repr(pair.purchase)
    assert "app-1" not in repr(pair.app)
    assert not hasattr(pair, "owner") and not hasattr(pair, "entitlement")


@pytest.mark.parametrize(("target", "field", "value"), [
    ("app", "bundleId", "other.bundle"), ("app", "appAppleId", 98765),
    ("app", "appAppleId", "123456"), ("app", "appAppleId", True),
    ("app", "receiptType", "Sandbox"), ("app", "receiptType", "Xcode"),
    ("app", "appTransactionId", None), ("purchase", "appTransactionId", "other-owner"),
    ("purchase", "environment", "Sandbox"), ("purchase", "bundleId", "other.bundle"),
    ("purchase", "productId", "other-product"),
    ("purchase", "subscriptionGroupIdentifier", "other-group"),
    ("purchase", "type", "Consumable"), ("purchase", "inAppOwnershipType", "FAMILY_SHARED"),
    ("purchase", "quantity", True), ("purchase", "quantity", "1"),
    ("purchase", "quantity", 1.0), ("purchase", "quantity", 2),
    ("purchase", "quantity", None), ("purchase", "quantity", 0),
    ("purchase", "quantity", -1), ("purchase", "quantity", []),
    ("purchase", "quantity", {}),
    ("purchase", "isUpgraded", True), ("purchase", "isUpgraded", 0),
    ("purchase", "isUpgraded", None), ("purchase", "isUpgraded", "false"),
    ("purchase", "isUpgraded", 0.0), ("purchase", "isUpgraded", []),
    ("purchase", "isUpgraded", {}), ("purchase", "price", 0),
    ("purchase", "price", -1), ("purchase", "signedDate", "123456"),
    ("purchase", "purchaseDate", True), ("purchase", "expiresDate", None),
    ("purchase", "transactionId", ""), ("purchase", "originalTransactionId", "bad\nID"),
    ("app", "deviceVerification", "%%%"), ("app", "deviceVerification", ""),
    ("app", "deviceVerificationNonce", "not-a-uuid"),
])
def test_claim_rejection_uses_authenticated_raw_types(evidence, target, field, value):
    verifier, app, purchase, sign, _, _ = evidence
    (app if target == "app" else purchase)[field] = value
    with pytest.raises(AppleEvidenceError):
        verifier.verify_pair(sign(app), sign(purchase))


@pytest.mark.parametrize("field", [
    "offerType", "offerIdentifier", "offerDiscountType", "offerPeriod", "revocationDate",
    "revocationReason", "revocationType", "revocationPercentage", "advancedCommerceInfo",
    "billingPlanType", "commitmentInfo",
])
def test_lifecycle_evidence_requires_separate_reconciliation(evidence, field):
    verifier, app, purchase, sign, _, _ = evidence
    purchase[field] = 1
    with pytest.raises(AppleEvidenceError):
        verifier.verify_pair(sign(app), sign(purchase))


@pytest.mark.parametrize("target", ["app", "purchase"])
@pytest.mark.parametrize("offset", [-300_001, 60_001])
def test_stale_or_future_evidence(evidence, target, offset):
    verifier, app, purchase, sign, _, now = evidence
    (app if target == "app" else purchase)[
        "receiptCreationDate" if target == "app" else "signedDate"] = now + offset
    with pytest.raises(AppleEvidenceError, match="evidence_not_fresh"):
        verifier.verify_pair(sign(app), sign(purchase))


@pytest.mark.parametrize("offset", [-1, 300_001])
def test_clock_checked_after_network_verification(evidence, offset):
    verifier, app, purchase, sign, _, now = evidence
    clock = iter([now, now + offset])
    verifier.clock_ms = lambda: next(clock)
    with pytest.raises(AppleEvidenceError, match="invalid_clock|evidence_not_fresh"):
        verifier.verify_pair(sign(app), sign(purchase))


def test_expired_purchase_is_evidence_not_entitlement(evidence):
    verifier, app, purchase, sign, _, now = evidence
    purchase["expiresDate"] = now - 1
    assert verifier.verify_pair(sign(app), sign(purchase)).purchase.expires_at_ms < now


@pytest.mark.parametrize("field", ["purchaseDate", "originalPurchaseDate", "expiresDate"])
def test_inconsistent_period_rejected(evidence, field):
    verifier, app, purchase, sign, _, now = evidence
    purchase[field] = now + 1000 if field != "expiresDate" else now - 1000
    with pytest.raises(AppleEvidenceError, match="invalid_period"):
        verifier.verify_pair(sign(app), sign(purchase))


def test_signature_tampering_rejected(evidence):
    verifier, app, purchase, sign, _, _ = evidence
    header, _, signature = sign(app).split(".")
    app["appTransactionId"] = "stolen-owner"
    payload = base64.urlsafe_b64encode(json.dumps(app).encode()).decode().rstrip("=")
    with pytest.raises(AppleEvidenceError, match="verification_failed"):
        verifier.verify_pair(f"{header}.{payload}.{signature}", sign(purchase))


def test_untrusted_chain_and_ocsp_failure_closed(evidence):
    verifier, app, purchase, sign, ocsp, _ = evidence
    ocsp.side_effect = OSError("sensitive-upstream-message")
    with pytest.raises(AppleEvidenceError, match="^verification_failed$") as caught:
        verifier.verify_pair(sign(app), sign(purchase))
    assert caught.value.__suppress_context__
    ocsp.side_effect = None
    verifier._sdk._chain_verifier.root_certificates = []
    with pytest.raises(AppleEvidenceError, match="verification_failed"):
        verifier.verify_pair(sign(app), sign(purchase))


@pytest.mark.parametrize("signed", ["", "a.b.c", "a.b", "a.b.c.d", "é", "x" * 32769])
def test_malformed_input_rejected(evidence, signed):
    verifier, _, purchase, sign, ocsp, _ = evidence
    with pytest.raises(AppleEvidenceError):
        verifier.verify_pair(signed, sign(purchase))
    ocsp.assert_not_called()


@pytest.mark.parametrize("payload", ['{"x":1,"x":2}', '{"x":NaN}', '{"x":Infinity}', '[]'])
def test_ambiguous_json_rejected_before_sdk(evidence, payload):
    verifier, app, purchase, sign, ocsp, _ = evidence
    header, _, signature = sign(app).split(".")
    encoded = base64.urlsafe_b64encode(payload.encode()).decode().rstrip("=")
    with pytest.raises(AppleEvidenceError, match="invalid_jws"):
        verifier.verify_pair(f"{header}.{encoded}.{signature}", sign(purchase))
    ocsp.assert_not_called()


@pytest.mark.parametrize("environment", [
    Environment.XCODE, Environment.LOCAL_TESTING, "Production",
])
def test_signature_bypass_environments_prohibited(evidence, environment):
    verifier, *_ = evidence
    with pytest.raises(AppleEvidenceError, match="invalid_environment"):
        replace(verifier.policy, environment=environment)


@pytest.mark.parametrize("roots", [(), [], (b"",), (b"x" * 16385,), (b"x",) * 5])
def test_trust_configuration_bounded(evidence, roots):
    verifier, *_ = evidence
    with pytest.raises(AppleEvidenceError, match="invalid_trust_configuration"):
        AppleEvidenceVerifier(verifier.policy, root_certificates=roots)
