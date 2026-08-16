"""Cryptographic regression tests for the App Attest verifier."""

import base64
import hashlib
import io
from datetime import UTC, datetime
from pathlib import Path

import cbor2
import pytest
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, utils

import app.auth.app_attest as app_attest_module
from app.auth.app_attest import AppAttestValidationError, AppAttestVerifier

APPLE_KEY_ID = "zgSY9YSD+7TaDXssY6WlOPVS1K3Lmk+pFhlcSWE+ZV0="
APPLE_APP_ID = "1234567890.com.example.myapp"
APPLE_CHALLENGE = b"example_server_challenge"
APPLE_VECTOR_TIME = datetime(2026, 4, 21, tzinfo=UTC)


def _official_vector() -> bytes:
    path = Path(__file__).parent / "fixtures" / "apple_app_attest_april_2026.b64"
    return base64.b64decode("".join(path.read_text().split()), validate=True)


def _official_vector_with_runtime_extensions(
    extensions: dict[str, object] | None,
) -> bytes:
    decoded = cbor2.loads(_official_vector())
    auth_data = decoded["authData"]
    offset = 37
    credential_length = int.from_bytes(auth_data[offset + 16 : offset + 18], "big")
    offset += 18 + credential_length
    cose_stream = io.BytesIO(auth_data[offset:])
    cbor2.CBORDecoder(cose_stream).decode()
    extension_offset = offset + cose_stream.tell()
    decoded["authData"] = auth_data[:extension_offset] + (
        cbor2.dumps(extensions, canonical=True) if extensions is not None else b""
    )
    return cbor2.dumps(decoded, canonical=True)


def _patch_official_fixture_nonce(monkeypatch, attestation_object: bytes) -> None:
    auth_data = cbor2.loads(attestation_object)["authData"]
    expected_nonce = hashlib.sha256(
        auth_data + hashlib.sha256(APPLE_CHALLENGE).digest()
    ).digest()
    monkeypatch.setattr(
        app_attest_module,
        "_decode_nonce_extension",
        lambda _value: expected_nonce,
    )


def test_official_apple_vector_reaches_normative_nonce_check() -> None:
    """Apple's April 2026 vector signs raw challenge, contrary to its prose.

    Reaching the nonce mismatch proves its pinned chain, App ID, AAGUID,
    credential ID, certified-public-key hash, and COSE/certificate key pair were
    all accepted first. The production verifier intentionally keeps the
    normative double-hash contract used by the iOS client; physical-device QA
    closes this upstream gap.
    """
    verifier = AppAttestVerifier(
        app_id=APPLE_APP_ID,
        environment="production",
        allowed_validation_categories=frozenset({1}),
        allowed_bundle_versions=frozenset({"1"}),
    )

    with pytest.raises(AppAttestValidationError, match="Attestation nonce mismatch"):
        verifier.verify_attestation(
            attestation_object=_official_vector(),
            key_id=base64.b64decode(APPLE_KEY_ID),
            challenge=APPLE_CHALLENGE,
            now=APPLE_VECTOR_TIME,
        )


def test_official_apple_vector_key_id_matches_certified_public_key_hash() -> None:
    decoded = cbor2.loads(_official_vector())
    leaf = x509.load_der_x509_certificate(decoded["attStmt"]["x5c"][0])
    leaf_key = leaf.public_key()
    assert isinstance(leaf_key, ec.EllipticCurvePublicKey)

    certified_key_bytes = leaf_key.public_bytes(
        serialization.Encoding.X962,
        serialization.PublicFormat.UncompressedPoint,
    )

    assert hashlib.sha256(certified_key_bytes).digest() == base64.b64decode(APPLE_KEY_ID)


def test_official_apple_vector_rejects_wrong_supplied_key_id() -> None:
    verifier = AppAttestVerifier(
        app_id=APPLE_APP_ID,
        environment="production",
        allowed_validation_categories=frozenset({1}),
        allowed_bundle_versions=frozenset({"1"}),
    )

    with pytest.raises(AppAttestValidationError, match="Credential identifier mismatch"):
        verifier.verify_attestation(
            attestation_object=_official_vector(),
            key_id=b"x" * 32,
            challenge=APPLE_CHALLENGE,
            now=APPLE_VECTOR_TIME,
        )


def test_attestation_rejects_key_id_not_hash_of_certified_public_key() -> None:
    decoded = cbor2.loads(_official_vector())
    auth_data = bytearray(decoded["authData"])
    credential_length_offset = 32 + 1 + 4 + 16
    credential_length = int.from_bytes(
        auth_data[credential_length_offset : credential_length_offset + 2],
        "big",
    )
    assert credential_length == 32
    credential_offset = credential_length_offset + 2
    mismatched_key_id = b"x" * 32
    auth_data[credential_offset : credential_offset + credential_length] = mismatched_key_id
    decoded["authData"] = bytes(auth_data)
    mutated_attestation = cbor2.dumps(decoded, canonical=True)

    verifier = AppAttestVerifier(
        app_id=APPLE_APP_ID,
        environment="production",
        allowed_validation_categories=frozenset({1}),
        allowed_bundle_versions=frozenset({"1"}),
    )

    with pytest.raises(AppAttestValidationError, match="Certified public key hash mismatch"):
        verifier.verify_attestation(
            attestation_object=mutated_attestation,
            key_id=mismatched_key_id,
            challenge=APPLE_CHALLENGE,
            now=APPLE_VECTOR_TIME,
        )


def test_attestation_rejects_unsupported_certificate_signature_algorithm() -> None:
    decoded = cbor2.loads(_official_vector())
    leaf = bytearray(decoded["attStmt"]["x5c"][0])
    ecdsa_sha256_oid = bytes.fromhex("06082a8648ce3d040302")
    offsets = [
        offset
        for offset in range(len(leaf))
        if leaf.startswith(ecdsa_sha256_oid, offset)
    ]
    assert len(offsets) == 2
    leaf[offsets[-1] + len(ecdsa_sha256_oid) - 1] = 0x7F
    decoded["attStmt"]["x5c"][0] = bytes(leaf)

    verifier = AppAttestVerifier(
        app_id=APPLE_APP_ID,
        environment="production",
        allowed_validation_categories=frozenset({1}),
        allowed_bundle_versions=frozenset({"1"}),
    )

    with pytest.raises(AppAttestValidationError, match="certificate signature"):
        verifier.verify_attestation(
            attestation_object=cbor2.dumps(decoded, canonical=True),
            key_id=base64.b64decode(APPLE_KEY_ID),
            challenge=APPLE_CHALLENGE,
            now=APPLE_VECTOR_TIME,
        )


def test_attestation_accepts_signed_absence_of_ios_27_runtime_extensions(
    monkeypatch,
) -> None:
    attestation = _official_vector_with_runtime_extensions(None)
    _patch_official_fixture_nonce(monkeypatch, attestation)
    verifier = AppAttestVerifier(
        app_id=APPLE_APP_ID,
        environment="production",
        allowed_validation_categories=frozenset({1}),
        allowed_bundle_versions=frozenset({"1"}),
    )

    result = verifier.verify_attestation(
        attestation_object=attestation,
        key_id=base64.b64decode(APPLE_KEY_ID),
        challenge=APPLE_CHALLENGE,
        now=APPLE_VECTOR_TIME,
    )

    assert result.validation_category is None
    assert result.bundle_version is None


@pytest.mark.parametrize(
    ("extensions", "error"),
    [
        ({"apple_validation_category_01": 1}, "Runtime extensions"),
        (
            {
                "apple_validation_category_01": 2,
                "apple_bundle_version_01": "1",
            },
            "Disallowed validation category",
        ),
        (
            {
                "apple_validation_category_01": 1,
                "apple_bundle_version_01": "999",
            },
            "Disallowed bundle version",
        ),
    ],
    ids=["partial", "disallowed-category", "disallowed-build"],
)
def test_attestation_rejects_partial_or_disallowed_runtime_extensions(
    monkeypatch,
    extensions: dict[str, object],
    error: str,
) -> None:
    attestation = _official_vector_with_runtime_extensions(extensions)
    _patch_official_fixture_nonce(monkeypatch, attestation)
    verifier = AppAttestVerifier(
        app_id=APPLE_APP_ID,
        environment="production",
        allowed_validation_categories=frozenset({1}),
        allowed_bundle_versions=frozenset({"1"}),
    )

    with pytest.raises(AppAttestValidationError, match=error):
        verifier.verify_attestation(
            attestation_object=attestation,
            key_id=base64.b64decode(APPLE_KEY_ID),
            challenge=APPLE_CHALLENGE,
            now=APPLE_VECTOR_TIME,
        )


@pytest.mark.parametrize("category", [2, b"\x02\x00\x00\x00"])
def test_assertion_accepts_documented_and_apple_vector_uint32_forms(
    category: int | bytes,
) -> None:
    private_key = ec.generate_private_key(ec.SECP256R1())
    public_key_der = private_key.public_key().public_bytes(
        serialization.Encoding.DER,
        serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    client_data = b'{"challenge":"abc","version":1}'
    auth_data = _assertion_auth_data(category=category, counter=7)
    nonce = hashlib.sha256(auth_data + hashlib.sha256(client_data).digest()).digest()
    signature = private_key.sign(
        nonce,
        ec.ECDSA(utils.Prehashed(hashes.SHA256())),
    )
    assertion = cbor2.dumps(
        {"signature": signature, "authenticatorData": auth_data},
        canonical=True,
    )
    verifier = _assertion_verifier()

    result = verifier.verify_assertion(
        assertion_object=assertion,
        client_data=client_data,
        public_key_der=public_key_der,
        previous_sign_count=6,
    )

    assert result.sign_count == 7
    assert result.validation_category == 2
    assert result.bundle_version == "7"


def test_assertion_rejects_double_hashed_signature() -> None:
    private_key = ec.generate_private_key(ec.SECP256R1())
    public_key_der = private_key.public_key().public_bytes(
        serialization.Encoding.DER,
        serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    client_data = b"client-data"
    auth_data = _assertion_auth_data(category=2, counter=1)
    nonce = hashlib.sha256(auth_data + hashlib.sha256(client_data).digest()).digest()
    # ECDSA(SHA256) hashes the already-hashed nonce again; App Attest signs the
    # nonce digest itself, so this representation must fail.
    signature = private_key.sign(nonce, ec.ECDSA(hashes.SHA256()))
    assertion = cbor2.dumps(
        {"signature": signature, "authenticatorData": auth_data},
        canonical=True,
    )

    with pytest.raises(AppAttestValidationError, match="Invalid assertion signature"):
        _assertion_verifier().verify_assertion(
            assertion_object=assertion,
            client_data=client_data,
            public_key_der=public_key_der,
            previous_sign_count=0,
        )


def test_assertion_rejects_wrong_relying_party_id() -> None:
    private_key = ec.generate_private_key(ec.SECP256R1())
    public_key_der = private_key.public_key().public_bytes(
        serialization.Encoding.DER,
        serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    client_data = b"client-data"
    auth_data = hashlib.sha256(b"OTHERPREFIX.com.tth.Wardrobe").digest() + b"\x00" + (
        1
    ).to_bytes(4, "big")
    nonce = hashlib.sha256(auth_data + hashlib.sha256(client_data).digest()).digest()
    signature = private_key.sign(nonce, ec.ECDSA(utils.Prehashed(hashes.SHA256())))
    assertion = cbor2.dumps(
        {"signature": signature, "authenticatorData": auth_data},
        canonical=True,
    )

    with pytest.raises(AppAttestValidationError, match="App ID mismatch"):
        _assertion_verifier().verify_assertion(
            assertion_object=assertion,
            client_data=client_data,
            public_key_der=public_key_der,
            previous_sign_count=0,
        )


@pytest.mark.parametrize(("counter", "previous"), [(0, 0), (7, 7), (6, 7)])
def test_assertion_rejects_non_monotonic_counter(counter: int, previous: int) -> None:
    private_key = ec.generate_private_key(ec.SECP256R1())
    public_key_der = private_key.public_key().public_bytes(
        serialization.Encoding.DER,
        serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    client_data = b"client-data"
    auth_data = hashlib.sha256(b"TESTPREFIX.com.tth.Wardrobe").digest() + b"\x00" + (
        counter
    ).to_bytes(4, "big")
    nonce = hashlib.sha256(auth_data + hashlib.sha256(client_data).digest()).digest()
    signature = private_key.sign(nonce, ec.ECDSA(utils.Prehashed(hashes.SHA256())))
    assertion = cbor2.dumps(
        {"signature": signature, "authenticatorData": auth_data},
        canonical=True,
    )

    with pytest.raises(AppAttestValidationError, match="counter replay"):
        _assertion_verifier().verify_assertion(
            assertion_object=assertion,
            client_data=client_data,
            public_key_der=public_key_der,
            previous_sign_count=previous,
        )


def test_assertion_accepts_signed_absence_of_ios_27_runtime_extensions() -> None:
    private_key = ec.generate_private_key(ec.SECP256R1())
    public_key_der = private_key.public_key().public_bytes(
        serialization.Encoding.DER,
        serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    client_data = b"client-data"
    auth_data = hashlib.sha256(b"TESTPREFIX.com.tth.Wardrobe").digest() + b"\x00" + (1).to_bytes(
        4, "big"
    )
    nonce = hashlib.sha256(auth_data + hashlib.sha256(client_data).digest()).digest()
    signature = private_key.sign(nonce, ec.ECDSA(utils.Prehashed(hashes.SHA256())))
    assertion = cbor2.dumps(
        {"signature": signature, "authenticatorData": auth_data},
        canonical=True,
    )

    result = _assertion_verifier().verify_assertion(
        assertion_object=assertion,
        client_data=client_data,
        public_key_der=public_key_der,
        previous_sign_count=0,
    )

    assert result.validation_category is None
    assert result.bundle_version is None


@pytest.mark.parametrize(
    "extensions",
    [
        {"apple_validation_category_01": 2},
        {"apple_bundle_version_01": "7"},
        {
            "apple_validation_category_01": True,
            "apple_bundle_version_01": "7",
        },
    ],
    ids=["missing-bundle", "missing-category", "malformed-category"],
)
def test_assertion_rejects_partial_or_malformed_runtime_extensions(extensions) -> None:
    private_key = ec.generate_private_key(ec.SECP256R1())
    public_key_der = private_key.public_key().public_bytes(
        serialization.Encoding.DER,
        serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    client_data = b"client-data"
    auth_data = (
        hashlib.sha256(b"TESTPREFIX.com.tth.Wardrobe").digest()
        + b"\x80"
        + (1).to_bytes(4, "big")
        + cbor2.dumps(extensions, canonical=True)
    )
    nonce = hashlib.sha256(auth_data + hashlib.sha256(client_data).digest()).digest()
    signature = private_key.sign(nonce, ec.ECDSA(utils.Prehashed(hashes.SHA256())))
    assertion = cbor2.dumps(
        {"signature": signature, "authenticatorData": auth_data},
        canonical=True,
    )

    with pytest.raises(
        AppAttestValidationError,
        match="Runtime extensions|validation category",
    ):
        _assertion_verifier().verify_assertion(
            assertion_object=assertion,
            client_data=client_data,
            public_key_der=public_key_der,
            previous_sign_count=0,
        )


@pytest.mark.parametrize(
    ("category", "bundle_version", "error"),
    [
        (3, "7", "Disallowed validation category"),
        (2, "8", "Disallowed bundle version"),
    ],
)
def test_assertion_rejects_present_disallowed_runtime_extensions(
    category: int,
    bundle_version: str,
    error: str,
) -> None:
    private_key = ec.generate_private_key(ec.SECP256R1())
    public_key_der = private_key.public_key().public_bytes(
        serialization.Encoding.DER,
        serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    client_data = b"client-data"
    auth_data = _assertion_auth_data(
        category=category,
        counter=1,
        bundle_version=bundle_version,
    )
    nonce = hashlib.sha256(auth_data + hashlib.sha256(client_data).digest()).digest()
    signature = private_key.sign(nonce, ec.ECDSA(utils.Prehashed(hashes.SHA256())))
    assertion = cbor2.dumps(
        {"signature": signature, "authenticatorData": auth_data},
        canonical=True,
    )

    with pytest.raises(AppAttestValidationError, match=error):
        _assertion_verifier().verify_assertion(
            assertion_object=assertion,
            client_data=client_data,
            public_key_der=public_key_der,
            previous_sign_count=0,
        )


def test_assertion_rejects_unsupported_stored_public_key_algorithm(monkeypatch) -> None:
    auth_data = hashlib.sha256(b"TESTPREFIX.com.tth.Wardrobe").digest() + b"\x00" + (1).to_bytes(
        4, "big"
    )
    assertion = cbor2.dumps(
        {"signature": b"signature", "authenticatorData": auth_data},
        canonical=True,
    )

    def unsupported_key(_value):
        from cryptography.exceptions import UnsupportedAlgorithm

        raise UnsupportedAlgorithm("unsupported stored key")

    monkeypatch.setattr(serialization, "load_der_public_key", unsupported_key)

    with pytest.raises(AppAttestValidationError, match="Invalid stored public key"):
        _assertion_verifier().verify_assertion(
            assertion_object=assertion,
            client_data=b"client-data",
            public_key_der=b"corrupt-restored-key",
            previous_sign_count=0,
        )


@pytest.mark.parametrize(
    "assertion_object",
    [
        b"\x81" * 401 + b"\x00",
        cbor2.dumps(
            {
                "signature": b"signature",
                "authenticatorData": (
                    hashlib.sha256(b"TESTPREFIX.com.tth.Wardrobe").digest()
                    + b"\x80"
                    + (1).to_bytes(4, "big")
                    + (b"\x81" * 401)
                    + b"\x00"
                ),
            },
            canonical=True,
        ),
    ],
    ids=["outer-object", "authenticator-extension"],
)
def test_assertion_rejects_excessively_nested_cbor(assertion_object: bytes) -> None:
    with pytest.raises(AppAttestValidationError, match="Malformed"):
        _assertion_verifier().verify_assertion(
            assertion_object=assertion_object,
            client_data=b"client-data",
            public_key_der=b"unused",
            previous_sign_count=0,
        )


def _assertion_auth_data(
    *,
    category: int | bytes,
    counter: int,
    bundle_version: str = "7",
) -> bytes:
    extensions = cbor2.dumps(
        {
            "apple_validation_category_01": category,
            "apple_bundle_version_01": bundle_version,
        },
        canonical=True,
    )
    return (
        hashlib.sha256(b"TESTPREFIX.com.tth.Wardrobe").digest()
        + b"\x80"
        + counter.to_bytes(4, "big")
        + extensions
    )


def _assertion_verifier() -> AppAttestVerifier:
    return AppAttestVerifier(
        app_id="TESTPREFIX.com.tth.Wardrobe",
        environment="production",
        allowed_validation_categories=frozenset({2}),
        allowed_bundle_versions=frozenset({"7"}),
    )
