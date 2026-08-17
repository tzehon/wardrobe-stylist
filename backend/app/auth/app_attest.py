"""Strict server-side verification for Apple App Attest objects.

This follows Apple's validation sequence: pinned certificate chain, nonce,
App ID, attested credential, monotonic assertion counter, and (when the OS
supplies them) runtime validation-category and bundle-version extensions.
"""

from __future__ import annotations

import hashlib
import io
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import cbor2
from cryptography import x509
from cryptography.exceptions import InvalidSignature, UnsupportedAlgorithm
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import ObjectIdentifier

from app.auth.config import AppAttestEnvironment

_APPLE_ROOT_SHA256 = bytes.fromhex(
    "1cb9823ba28ba6ad2d33a006941de2ae4f513ef1d4e831b9f7e0fa7b6242c932"
)
_NONCE_EXTENSION_OID = ObjectIdentifier("1.2.840.113635.100.8.2")
_PRODUCTION_AAGUID = b"appattest" + (b"\x00" * 7)
_DEVELOPMENT_AAGUIDS = {b"appattestdevelop", b"appattestsandbox"}
_ATTESTED_CREDENTIAL_DATA = 0x40
_EXTENSION_DATA = 0x80


class AppAttestValidationError(ValueError):
    """A deliberately non-specific cryptographic validation failure."""


@dataclass(frozen=True)
class AttestationResult:
    public_key_der: bytes
    opaque_receipt: bytes
    validation_category: int | None
    bundle_version: str | None


@dataclass(frozen=True)
class AssertionResult:
    sign_count: int
    validation_category: int | None
    bundle_version: str | None


@dataclass(frozen=True)
class _AuthenticatorData:
    rp_id_hash: bytes
    flags: int
    sign_count: int
    aaguid: bytes | None
    credential_id: bytes | None
    cose_key: dict[Any, Any] | None
    extensions: dict[Any, Any] | None


class AppAttestVerifier:
    def __init__(
        self,
        *,
        app_id: str,
        environment: AppAttestEnvironment,
        allowed_validation_categories: frozenset[int],
        allowed_bundle_versions: frozenset[str],
        root_certificate_pem: bytes | None = None,
    ) -> None:
        self.app_id = app_id
        self.environment = environment
        self.allowed_validation_categories = allowed_validation_categories
        self.allowed_bundle_versions = allowed_bundle_versions
        root_pem = root_certificate_pem or Path(__file__).with_name(
            "Apple_App_Attestation_Root_CA.pem"
        ).read_bytes()
        self.root_certificate = x509.load_pem_x509_certificate(root_pem)
        if self.root_certificate.fingerprint(hashes.SHA256()) != _APPLE_ROOT_SHA256:
            raise AppAttestValidationError("Untrusted App Attest root certificate.")

    def verify_attestation(
        self,
        *,
        attestation_object: bytes,
        key_id: bytes,
        challenge: bytes,
        now: datetime | None = None,
    ) -> AttestationResult:
        if len(key_id) != 32:
            raise AppAttestValidationError("Invalid key identifier.")
        decoded = _single_cbor(attestation_object)
        if not isinstance(decoded, dict) or set(decoded) != {"fmt", "attStmt", "authData"}:
            raise AppAttestValidationError("Invalid attestation object.")
        if decoded["fmt"] != "apple-appattest":
            raise AppAttestValidationError("Invalid attestation format.")
        statement = decoded["attStmt"]
        auth_data = decoded["authData"]
        if not isinstance(statement, dict) or set(statement) != {"x5c", "receipt"}:
            raise AppAttestValidationError("Invalid attestation statement.")
        chain = statement["x5c"]
        receipt = statement["receipt"]
        if (
            not isinstance(chain, list)
            or len(chain) != 2
            or not all(isinstance(cert, bytes) for cert in chain)
            or not isinstance(receipt, bytes)
            or not receipt
            or not isinstance(auth_data, bytes)
        ):
            raise AppAttestValidationError("Invalid attestation statement values.")

        checked_at = (now or datetime.now(UTC)).astimezone(UTC)
        leaf = x509.load_der_x509_certificate(chain[0])
        intermediate = x509.load_der_x509_certificate(chain[1])
        self._verify_certificate_chain(leaf, intermediate, checked_at)

        parsed = _parse_authenticator_data(auth_data, attestation=True)
        if parsed.rp_id_hash != hashlib.sha256(self.app_id.encode("utf-8")).digest():
            raise AppAttestValidationError("App ID mismatch.")
        if parsed.sign_count != 0:
            raise AppAttestValidationError("Attestation counter was not zero.")
        expected_aaguids = (
            {_PRODUCTION_AAGUID}
            if self.environment == "production"
            else _DEVELOPMENT_AAGUIDS
        )
        if parsed.aaguid not in expected_aaguids:
            raise AppAttestValidationError("App Attest environment mismatch.")
        if parsed.credential_id != key_id:
            raise AppAttestValidationError("Credential identifier mismatch.")

        leaf_key = leaf.public_key()
        if not isinstance(leaf_key, ec.EllipticCurvePublicKey) or not isinstance(
            leaf_key.curve, ec.SECP256R1
        ):
            raise AppAttestValidationError("Unexpected credential public key.")
        certified_key_bytes = leaf_key.public_bytes(
            serialization.Encoding.X962,
            serialization.PublicFormat.UncompressedPoint,
        )
        if hashlib.sha256(certified_key_bytes).digest() != key_id:
            raise AppAttestValidationError("Certified public key hash mismatch.")
        _verify_cose_key(parsed.cose_key, leaf_key)

        nonce = hashlib.sha256(auth_data + hashlib.sha256(challenge).digest()).digest()
        extension = leaf.extensions.get_extension_for_oid(_NONCE_EXTENSION_OID).value
        if not isinstance(extension, x509.UnrecognizedExtension):
            raise AppAttestValidationError("Invalid nonce extension.")
        certificate_nonce = _decode_nonce_extension(extension.value)
        if certificate_nonce != nonce:
            raise AppAttestValidationError("Attestation nonce mismatch.")

        category, bundle_version = self._validate_runtime_extensions(parsed.extensions)
        public_key_der = leaf_key.public_bytes(
            serialization.Encoding.DER,
            serialization.PublicFormat.SubjectPublicKeyInfo,
        )
        return AttestationResult(
            public_key_der=public_key_der,
            # The receipt is opaque evidence from an otherwise verified core
            # attestation. PKCS#7 payload/risk-metric assessment is a separate
            # operational step; do not describe this blob itself as verified.
            opaque_receipt=receipt,
            validation_category=category,
            bundle_version=bundle_version,
        )

    def verify_assertion(
        self,
        *,
        assertion_object: bytes,
        client_data: bytes,
        public_key_der: bytes,
        previous_sign_count: int,
    ) -> AssertionResult:
        decoded = _single_cbor(assertion_object)
        if not isinstance(decoded, dict) or set(decoded) != {"signature", "authenticatorData"}:
            raise AppAttestValidationError("Invalid assertion object.")
        signature = decoded["signature"]
        auth_data = decoded["authenticatorData"]
        if not isinstance(signature, bytes) or not signature or not isinstance(auth_data, bytes):
            raise AppAttestValidationError("Invalid assertion values.")

        parsed = _parse_authenticator_data(auth_data, attestation=False)
        if parsed.rp_id_hash != hashlib.sha256(self.app_id.encode("utf-8")).digest():
            raise AppAttestValidationError("App ID mismatch.")
        if parsed.sign_count <= 0 or parsed.sign_count <= previous_sign_count:
            raise AppAttestValidationError("Assertion counter replay.")

        try:
            public_key = serialization.load_der_public_key(public_key_der)
        except (ValueError, UnsupportedAlgorithm) as exc:
            raise AppAttestValidationError("Invalid stored public key.") from exc
        if not isinstance(public_key, ec.EllipticCurvePublicKey) or not isinstance(
            public_key.curve, ec.SECP256R1
        ):
            raise AppAttestValidationError("Invalid stored public key.")
        nonce = hashlib.sha256(auth_data + hashlib.sha256(client_data).digest()).digest()
        try:
            # Apple defines nonce as SHA256(authenticatorData ||
            # SHA256(clientData)), then signs that nonce using ECDSA-SHA256.
            # The ECDSA algorithm therefore hashes the 32-byte nonce message;
            # treating nonce as a prehashed digest rejects physical-device
            # assertions even though their key, RP ID, and counter are valid.
            public_key.verify(
                signature,
                nonce,
                ec.ECDSA(hashes.SHA256()),
            )
        except InvalidSignature as exc:
            raise AppAttestValidationError("Invalid assertion signature.") from exc

        category, bundle_version = self._validate_runtime_extensions(parsed.extensions)
        return AssertionResult(
            sign_count=parsed.sign_count,
            validation_category=category,
            bundle_version=bundle_version,
        )

    def _verify_certificate_chain(
        self,
        leaf: x509.Certificate,
        intermediate: x509.Certificate,
        now: datetime,
    ) -> None:
        for certificate in (leaf, intermediate, self.root_certificate):
            if not certificate.not_valid_before_utc <= now <= certificate.not_valid_after_utc:
                raise AppAttestValidationError("Expired App Attest certificate.")
        if (
            leaf.issuer != intermediate.subject
            or intermediate.issuer != self.root_certificate.subject
        ):
            raise AppAttestValidationError("Invalid App Attest certificate chain.")
        _verify_certificate_signature(leaf, intermediate)
        _verify_certificate_signature(intermediate, self.root_certificate)

        leaf_constraints = leaf.extensions.get_extension_for_class(x509.BasicConstraints).value
        intermediate_constraints = intermediate.extensions.get_extension_for_class(
            x509.BasicConstraints
        ).value
        if leaf_constraints.ca or not intermediate_constraints.ca:
            raise AppAttestValidationError("Invalid App Attest basic constraints.")
        leaf_usage = leaf.extensions.get_extension_for_class(x509.KeyUsage).value
        intermediate_usage = intermediate.extensions.get_extension_for_class(x509.KeyUsage).value
        if not leaf_usage.digital_signature or not intermediate_usage.key_cert_sign:
            raise AppAttestValidationError("Invalid App Attest key usage.")

    def _validate_runtime_extensions(
        self,
        extensions: dict[Any, Any] | None,
    ) -> tuple[int | None, str | None]:
        # App Attest runtime validation extensions are available on iOS 27 and
        # later. Their signed absence is the expected legacy-core shape on the
        # app's iOS 18-26 deployment range. If an OS supplies any runtime
        # extension, however, the pair must be complete and strictly allowed.
        if extensions is None:
            return None, None
        if set(extensions) != {
            "apple_validation_category_01",
            "apple_bundle_version_01",
        }:
            raise AppAttestValidationError("Runtime extensions must be complete.")
        raw_category = extensions["apple_validation_category_01"]
        if (
            isinstance(raw_category, int)
            and not isinstance(raw_category, bool)
            and 0 <= raw_category <= 0xFFFFFFFF
        ):
            category = raw_category
        elif isinstance(raw_category, bytes) and len(raw_category) == 4:
            # Apple's prose calls this a UInt32, while its April 2026
            # validation vector encodes the value as four little-endian bytes.
            category = int.from_bytes(raw_category, "little")
        else:
            raise AppAttestValidationError("Invalid validation category.")
        bundle_version = extensions["apple_bundle_version_01"]
        if not isinstance(bundle_version, str) or not bundle_version:
            raise AppAttestValidationError("Invalid bundle version.")
        if category not in self.allowed_validation_categories:
            raise AppAttestValidationError("Disallowed validation category.")
        if bundle_version not in self.allowed_bundle_versions:
            raise AppAttestValidationError("Disallowed bundle version.")
        return category, bundle_version


def _single_cbor(data: bytes) -> Any:
    if not data:
        raise AppAttestValidationError("Empty CBOR object.")
    stream = io.BytesIO(data)
    try:
        decoded: Any = cbor2.CBORDecoder(stream).decode()
    except (cbor2.CBORDecodeError, EOFError, ValueError, TypeError) as exc:
        raise AppAttestValidationError("Malformed CBOR object.") from exc
    if stream.read(1):
        raise AppAttestValidationError("Trailing CBOR data.")
    return decoded


def _parse_authenticator_data(data: bytes, *, attestation: bool) -> _AuthenticatorData:
    if len(data) < 37:
        raise AppAttestValidationError("Truncated authenticator data.")
    rp_id_hash = data[:32]
    flags = data[32]
    sign_count = int.from_bytes(data[33:37], "big")
    offset = 37
    aaguid: bytes | None = None
    credential_id: bytes | None = None
    cose_key: dict[Any, Any] | None = None

    if attestation:
        if not flags & _ATTESTED_CREDENTIAL_DATA:
            raise AppAttestValidationError("Attested credential data is missing.")
        if len(data) < offset + 18:
            raise AppAttestValidationError("Truncated attested credential data.")
        aaguid = data[offset : offset + 16]
        credential_length = int.from_bytes(data[offset + 16 : offset + 18], "big")
        offset += 18
        if credential_length <= 0 or len(data) < offset + credential_length:
            raise AppAttestValidationError("Invalid credential identifier length.")
        credential_id = data[offset : offset + credential_length]
        offset += credential_length
        cose_key_value, offset = _decode_cbor_at(data, offset)
        if not isinstance(cose_key_value, dict):
            raise AppAttestValidationError("Invalid COSE public key.")
        cose_key = cose_key_value
    elif flags & _ATTESTED_CREDENTIAL_DATA:
        # Physical iOS 26 App Attest assertions can set WebAuthn's AT bit while
        # still returning the documented 37-byte assertion authenticator data
        # with no attested-credential suffix. Treat the signed flag as opaque
        # for assertions. Any actual suffix is still required below to decode
        # as exactly one runtime-extension map, so credential data cannot be
        # smuggled through this compatibility path.
        pass

    extensions: dict[Any, Any] | None = None
    if flags & _EXTENSION_DATA or offset < len(data):
        # Apple's April 2026 validation vector appends the required extension
        # map while leaving the WebAuthn ED bit clear. Accept that published
        # representation, but still require exactly one terminal map.
        extension_value, offset = _decode_cbor_at(data, offset)
        if not isinstance(extension_value, dict):
            raise AppAttestValidationError("Invalid authenticator extensions.")
        extensions = extension_value
    if offset != len(data):
        raise AppAttestValidationError("Unexpected authenticator data suffix.")
    return _AuthenticatorData(
        rp_id_hash=rp_id_hash,
        flags=flags,
        sign_count=sign_count,
        aaguid=aaguid,
        credential_id=credential_id,
        cose_key=cose_key,
        extensions=extensions,
    )


def _decode_cbor_at(data: bytes, offset: int) -> tuple[Any, int]:
    stream = io.BytesIO(data[offset:])
    try:
        decoded: Any = cbor2.CBORDecoder(stream).decode()
    except (cbor2.CBORDecodeError, EOFError, ValueError, TypeError) as exc:
        raise AppAttestValidationError("Malformed authenticator CBOR.") from exc
    consumed = stream.tell()
    if consumed <= 0:
        raise AppAttestValidationError("Empty authenticator CBOR.")
    return decoded, offset + consumed


def _verify_cose_key(
    cose_key: dict[Any, Any] | None,
    certificate_key: ec.EllipticCurvePublicKey,
) -> None:
    if cose_key is None or set(cose_key) != {1, 3, -1, -2, -3}:
        raise AppAttestValidationError("Invalid COSE key fields.")
    if cose_key[1] != 2 or cose_key[3] != -7 or cose_key[-1] != 1:
        raise AppAttestValidationError("Invalid COSE key algorithm.")
    x_coordinate = cose_key[-2]
    y_coordinate = cose_key[-3]
    if (
        not isinstance(x_coordinate, bytes)
        or len(x_coordinate) != 32
        or not isinstance(y_coordinate, bytes)
        or len(y_coordinate) != 32
    ):
        raise AppAttestValidationError("Invalid COSE key coordinates.")
    numbers = certificate_key.public_numbers()
    if numbers.x.to_bytes(32, "big") != x_coordinate or numbers.y.to_bytes(
        32, "big"
    ) != y_coordinate:
        raise AppAttestValidationError("COSE and certificate keys differ.")


def _verify_certificate_signature(
    certificate: x509.Certificate,
    issuer: x509.Certificate,
) -> None:
    public_key = issuer.public_key()
    if not isinstance(public_key, ec.EllipticCurvePublicKey):
        raise AppAttestValidationError("Unexpected certificate key algorithm.")
    try:
        signature_hash_algorithm = certificate.signature_hash_algorithm
        if signature_hash_algorithm is None:
            raise AppAttestValidationError("Missing certificate signature hash.")
        public_key.verify(
            certificate.signature,
            certificate.tbs_certificate_bytes,
            ec.ECDSA(signature_hash_algorithm),
        )
    except (InvalidSignature, UnsupportedAlgorithm, ValueError) as exc:
        raise AppAttestValidationError("Invalid certificate signature.") from exc


def _decode_nonce_extension(data: bytes) -> bytes:
    sequence, end = _read_der_value(data, 0, expected_tag=0x30)
    if end != len(data):
        raise AppAttestValidationError("Trailing nonce extension data.")
    context, context_end = _read_der_value(sequence, 0, expected_tag=0xA1)
    if context_end != len(sequence):
        raise AppAttestValidationError("Invalid nonce extension sequence.")
    nonce, nonce_end = _read_der_value(context, 0, expected_tag=0x04)
    if nonce_end != len(context) or len(nonce) != 32:
        raise AppAttestValidationError("Invalid nonce extension value.")
    return nonce


def _read_der_value(data: bytes, offset: int, *, expected_tag: int) -> tuple[bytes, int]:
    if offset >= len(data) or data[offset] != expected_tag:
        raise AppAttestValidationError("Unexpected DER tag.")
    offset += 1
    if offset >= len(data):
        raise AppAttestValidationError("Truncated DER length.")
    first_length = data[offset]
    offset += 1
    if first_length & 0x80:
        length_octets = first_length & 0x7F
        if length_octets == 0 or length_octets > 4 or offset + length_octets > len(data):
            raise AppAttestValidationError("Invalid DER length.")
        if data[offset] == 0:
            raise AppAttestValidationError("Non-minimal DER length.")
        length = int.from_bytes(data[offset : offset + length_octets], "big")
        offset += length_octets
        if length < 128:
            raise AppAttestValidationError("Non-minimal DER length.")
    else:
        length = first_length
    end = offset + length
    if end > len(data):
        raise AppAttestValidationError("Truncated DER value.")
    return data[offset:end], end
