"""Real ES256/chain verification with ephemeral synthetic certificates, NOT Apple fixtures.

Only OCSP is stubbed; these tests prove the adapter boundary, not device ownership
or compatibility with live Apple data. No private key or receipt is retained.
"""

import base64
import json
import time
from dataclasses import replace
from datetime import UTC, datetime, timedelta
from pathlib import Path
from unittest.mock import Mock

import cbor2
import jwt
import pytest
from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.signed_data_verifier import _ChainVerifier
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec

from app.auth.app_attest import AppAttestVerifier
from app.auth.store import InstallationRecord
from app.commerce.apple_evidence import (
    AppleEvidenceError,
    AppleEvidencePolicy,
    AppleEvidenceVerifier,
)
from app.commerce.ownership_evidence import (
    OwnershipEvidenceError,
    ProofChallenge,
    device_digest,
    inspect_app_request,
    proof_transcript,
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


def test_app_evidence_requires_no_purchase(evidence):
    verifier, app, _, sign, _, now = evidence
    result = verifier.verify_app(sign(app))
    assert result.app_transaction_id == "app-1"
    assert result.signed_at_ms == now
    assert not hasattr(result, "owner") and not hasattr(result, "entitlement")


@pytest.mark.parametrize("field,value", [
    ("appTransactionId", None), ("appAppleId", "123456"), ("bundleId", "other.bundle"),
    ("receiptType", "LocalTesting"), ("receiptCreationDate", 1),
])
def test_app_only_path_retains_claim_guards(evidence, field, value):
    verifier, app, _, sign, _, _ = evidence
    app[field] = value
    with pytest.raises(AppleEvidenceError):
        verifier.verify_app(sign(app))


def test_app_only_path_rejects_network_clock_regression(evidence):
    verifier, app, _, sign, _, now = evidence
    clock = iter([now, now - 1])
    verifier.clock_ms = lambda: next(clock)
    with pytest.raises(AppleEvidenceError, match="invalid_clock"):
        verifier.verify_app(sign(app))


@pytest.fixture
def app_request(evidence):
    apple, app, _, sign, _, now = evidence
    import hashlib

    private = ec.generate_private_key(ec.SECP256R1())
    key_id = base64.b64encode(hashlib.sha256(private.public_key().public_bytes(
        serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint,
    )).digest()).decode()
    installation = InstallationRecord(
        installation_id="9d9443c8-8be9-4415-b864-3b1a38f2521c", key_id=key_id,
        public_key_der=private.public_key().public_bytes(
            serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo),
        opaque_receipt=b"synthetic", app_id="TESTPREFIX.com.example.wardrobe",
        attest_environment="production", sign_count=3, validation_category=None,
        bundle_version=None, revoked_at=None,
    )
    challenge = ProofChallenge("c2e8c04a-1e6f-4551-9e46-ebd46be9fa31", bytes(range(32)),
                               installation.installation_id, key_id, 7, now - 1000, now + 60_000)
    device_id = "8bb12c22-c7c4-4b2a-af07-95cb3382d5a1"
    app["deviceVerification"] = base64.b64encode(device_digest(
        app["deviceVerificationNonce"], device_id)).decode()
    jws = sign(app)
    attest = AppAttestVerifier(app_id=installation.app_id, environment="production",
                              allowed_validation_categories=frozenset({4}),
                              allowed_bundle_versions=frozenset({"8"}))

    def assertion(transcript, counter=4):
        auth = hashlib.sha256(installation.app_id.encode()).digest() + b"\x00"
        auth += counter.to_bytes(4, "big")
        nonce = hashlib.sha256(auth + hashlib.sha256(transcript).digest()).digest()
        return cbor2.dumps({"authenticatorData": auth,
                           "signature": private.sign(nonce, ec.ECDSA(hashes.SHA256()))})

    request = dict(challenge=challenge, installation=installation, app_jws=jws,
                   device_id=device_id, apple=apple, attest=attest,
                   assertion_object=assertion(proof_transcript(challenge, jws, device_id)))
    return request, assertion, now, app, sign


def test_attested_app_request_is_only_inspected_evidence(app_request):
    request, _, _, _, _ = app_request
    result = inspect_app_request(**request)
    assert result.assertion.sign_count == 4 and result.app.app_transaction_id == "app-1"
    assert not hasattr(result, "owner") and not hasattr(result, "grant")
    assert "app-1" not in repr(result) and request["device_id"] not in repr(result)
    # This deliberately proves the helper is NOT the durable replay gate. The
    # unchanged snapshot can be inspected again; a service must commit its counter.
    assert inspect_app_request(**request) == result
    request["installation"] = replace(request["installation"], sign_count=4)
    with pytest.raises(OwnershipEvidenceError, match="verification_failed"):
        inspect_app_request(**request)


@pytest.mark.parametrize("field,value", [
    ("binding_revision", 8), ("nonce", bytes(range(1, 33))),
    ("challenge_id", "3d362c2e-47dd-4c61-a8e6-64704f2d8cf4"),
])
def test_assertion_cannot_be_replayed_into_another_challenge(app_request, field, value):
    request, _, _, _, _ = app_request
    request["challenge"] = replace(request["challenge"], **{field: value})
    with pytest.raises(OwnershipEvidenceError):
        inspect_app_request(**request)


def test_assertion_binds_exact_jws_and_device_id(app_request):
    request, _, _, app, sign = app_request
    app["appTransactionId"] = "replacement-account"
    with pytest.raises(OwnershipEvidenceError):
        inspect_app_request(**{**request, "app_jws": sign(app)})
    with pytest.raises(OwnershipEvidenceError):
        inspect_app_request(**{**request, "device_id": "55722524-6e62-48ce-a9d4-3ef0840af4bc"})


def test_valid_assertion_does_not_make_wrong_device_hash_match(app_request):
    request, assertion, _, _, _ = app_request
    request["device_id"] = "55722524-6e62-48ce-a9d4-3ef0840af4bc"
    request["assertion_object"] = assertion(proof_transcript(
        request["challenge"], request["app_jws"], request["device_id"]))
    with pytest.raises(OwnershipEvidenceError, match="device_mismatch"):
        inspect_app_request(**request)


def test_signature_is_not_a_certificate_of_device_uuid_origin(app_request):
    request, _, _, _, _ = app_request
    # A synthetic legitimate key can sign an arbitrary matching UUID/JWS pair.
    # App Attest authenticates those bytes, not their StoreKit/hardware origin.
    # Preserve this counterexample: this result must never become an ownership grant.
    import hashlib

    other_key = ec.generate_private_key(ec.SECP256R1())
    other_id = base64.b64encode(hashlib.sha256(other_key.public_key().public_bytes(
        serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint,
    )).digest()).decode()
    other_installation = replace(
        request["installation"], installation_id="b122842e-420a-45c9-be56-218bb9cab3d4",
        key_id=other_id, sign_count=0,
        public_key_der=other_key.public_key().public_bytes(
            serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo),
    )
    other_challenge = replace(request["challenge"], key_id=other_id,
                              installation_id=other_installation.installation_id, nonce=b"z" * 32)
    transcript = proof_transcript(other_challenge, request["app_jws"], request["device_id"])
    auth = hashlib.sha256(other_installation.app_id.encode()).digest() + b"\x00\x00\x00\x00\x01"
    nonce = hashlib.sha256(auth + hashlib.sha256(transcript).digest()).digest()
    other_assertion = cbor2.dumps({"authenticatorData": auth,
                                  "signature": other_key.sign(nonce, ec.ECDSA(hashes.SHA256()))})
    borrowed = inspect_app_request(**{**request, "installation": other_installation,
                                     "challenge": other_challenge,
                                     "assertion_object": other_assertion})
    assert borrowed.app == inspect_app_request(**request).app
    assert not hasattr(borrowed, "owner")


@pytest.mark.parametrize("field,value", [
    ("revoked_at", 1), ("installation_id", "3d362c2e-47dd-4c61-a8e6-64704f2d8cf4"),
    ("key_id", base64.b64encode(b"x" * 32).decode()),
    ("app_id", "OTHER.com.example.wardrobe"), ("attest_environment", "development"),
])
def test_server_installation_snapshot_must_match(app_request, field, value):
    request, _, _, _, _ = app_request
    request["installation"] = replace(request["installation"], **{field: value})
    with pytest.raises(OwnershipEvidenceError, match="installation_mismatch"):
        inspect_app_request(**request)


@pytest.mark.parametrize("offset", [-1, 60_000])
def test_challenge_rechecked_after_online_verification(app_request, offset):
    request, _, now, _, _ = app_request
    clock = iter([now, now, now, now + offset])
    request["apple"].clock_ms = lambda: next(clock)
    with pytest.raises(OwnershipEvidenceError, match="expired_challenge|invalid_clock"):
        inspect_app_request(**request)


@pytest.mark.parametrize("offsets", [
    [0, 100, 200, 50],  # Regression after the verifier's completion sample.
    [100, 0, 50, 200],  # Regression between inspector and verifier entry.
    [0, 100, 70_000, 50],  # Expired challenge must not become fresh again.
])
def test_clock_cannot_regress_between_inspector_and_verifier_samples(app_request, offsets):
    request, _, now, _, _ = app_request
    clock = iter(now + offset for offset in offsets)
    request["apple"].clock_ms = lambda: next(clock)
    with pytest.raises(OwnershipEvidenceError, match="invalid_clock|verification_failed"):
        inspect_app_request(**request)


@pytest.mark.parametrize("field,value", [
    ("nonce", b"x" * 31), ("binding_revision", True), ("binding_revision", -1),
    ("binding_revision", 2**53), ("key_id", "a" * 44),
    ("challenge_id", "c2e8c04a1e6f45519e46ebd46be9fa31"),
    ("installation_id", "00000000-0000-0000-0000-000000000000"),
    ("issued_at_ms", False), ("expires_at_ms", 0),
])
def test_invalid_challenge_shapes_rejected(app_request, field, value):
    request, _, _, _, _ = app_request
    with pytest.raises(OwnershipEvidenceError):
        replace(request["challenge"], **{field: value})


def test_transcript_and_device_hash_match_shared_golden():
    import hashlib

    vector = json.loads((Path(__file__).parents[2] / "shared/fixtures/commerce-app-proof.json")
                        .read_text())
    challenge = ProofChallenge(vector["challenge_id"], bytes.fromhex(vector["nonce_hex"]),
                               vector["installation_id"], vector["key_id_base64"],
                               vector["binding_revision"], vector["issued_at_ms"],
                               vector["expires_at_ms"])
    transcript = proof_transcript(challenge, vector["app_jws"], vector["device_id"])
    assert transcript.decode() == vector["transcript"]
    assert hashlib.sha256(transcript).hexdigest() == vector["transcript_sha256"]
    assert device_digest(vector["device_nonce"], vector["device_id"]).hex() == (
        vector["device_digest_hex"])
