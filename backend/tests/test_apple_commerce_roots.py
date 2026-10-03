"""Offline provenance/negative checks, not positive live Apple receipt evidence."""

import hashlib
from datetime import UTC, datetime
from pathlib import Path
from unittest.mock import Mock

import pytest
from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.signed_data_verifier import (
    SignedDataVerifier,
    VerificationException,
    _ChainVerifier,
)
from cryptography import x509
from cryptography.hazmat.primitives.asymmetric import padding, rsa

FIXTURES = Path(__file__).parent / "fixtures/apple_commerce"
ROOTS = {
    "AppleIncRootCertificate.cer": (
        "b0b1730ecbc7ff4505142c49f1295e6eda6bcaed7e2c68c5be91b5a11001f024"),
    "AppleRootCA-G2.cer": "c2b9b042dd57830e7d117dac55ac8ae19407d38e41d88f3215bc3a890444a050",
    "AppleRootCA-G3.cer": "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179",
}


@pytest.mark.parametrize("name,digest", ROOTS.items())
def test_downloaded_official_root_identity_and_self_signature(name, digest):
    data = (FIXTURES / "roots" / name).read_bytes()
    assert hashlib.sha256(data).hexdigest() == digest
    cert = x509.load_der_x509_certificate(data)
    key = cert.public_key()
    if isinstance(key, rsa.RSAPublicKey):
        # The fingerprint-pinned 2006 root has a SHA-1 self-signature. Inspect
        # that historical signature only; this never relaxes SDK chain policy.
        key.verify(cert.signature, cert.tbs_certificate_bytes,
                   padding.PKCS1v15(), cert.signature_hash_algorithm)
    else:
        cert.verify_directly_issued_by(cert)
    assert cert.extensions.get_extension_for_class(x509.BasicConstraints).value.ca
    # Historical acquisition evidence, not a substitute for live validity/OCSP.
    assert cert.not_valid_before_utc <= datetime(2026, 10, 3, tzinfo=UTC) < cert.not_valid_after_utc


def test_upstream_mock_is_not_evidence_signed_under_apples_production_roots(monkeypatch):
    ocsp = Mock(side_effect=AssertionError("This negative fixture must not perform network I/O"))
    monkeypatch.setattr(_ChainVerifier, "check_ocsp_status", ocsp)
    verifier = SignedDataVerifier(
        [(FIXTURES / "roots" / name).read_bytes() for name in ROOTS],
        True, Environment.SANDBOX, "com.example", 1234,
    )
    with pytest.raises(VerificationException):
        verifier.verify_and_decode_signed_transaction(
            (FIXTURES / "upstream_mock_transaction.jws").read_text())
    ocsp.assert_not_called()
