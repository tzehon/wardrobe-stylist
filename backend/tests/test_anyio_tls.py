"""Certificate identity must use the same IDNA rules as DNS resolution."""

import ssl
from datetime import UTC, datetime, timedelta

import anyio
import pytest
from anyio.abc import ByteStream
from anyio.streams.tls import TLSStream
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID


class MemoryTLSServer(ByteStream):
    """Exercise real certificate verification without network or external services."""

    def __init__(self, context: ssl.SSLContext):
        self.incoming = ssl.MemoryBIO()
        self.outgoing = ssl.MemoryBIO()
        self.server = context.wrap_bio(self.incoming, self.outgoing, server_side=True)

    async def send(self, item: bytes) -> None:
        self.incoming.write(item)
        try:
            self.server.do_handshake()
        except ssl.SSLWantReadError:
            pass

    async def receive(self, max_bytes: int = 65536) -> bytes:
        data = self.outgoing.read(max_bytes)
        assert data, "TLS handshake stalled"
        return data

    async def send_eof(self) -> None:
        self.incoming.write_eof()

    async def aclose(self) -> None:
        pass


@pytest.mark.parametrize(
    ("hostname", "certificate_name", "accepted"),
    [
        ("faß.de", "fass.de", False),
        ("straße.example", "strasse.example", False),
        ("faß.de", "xn--fa-hia.de", True),
        ("xn--fa-hia.de", "xn--fa-hia.de", True),
        ("api.anthropic.com", "api.anthropic.com", True),
    ],
)
def test_tls_certificate_identity_uses_idna2008(
    tmp_path,
    hostname: str,
    certificate_name: str,
    accepted: bool,
) -> None:
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, certificate_name)])
    now = datetime.now(UTC)
    certificate = (
        x509.CertificateBuilder()
        .subject_name(name)
        .issuer_name(name)
        .public_key(key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now - timedelta(minutes=1))
        .not_valid_after(now + timedelta(hours=1))
        .add_extension(x509.SubjectAlternativeName([x509.DNSName(certificate_name)]), False)
        .sign(key, hashes.SHA256())
    )
    pem = certificate.public_bytes(serialization.Encoding.PEM)
    cert_path, key_path = tmp_path / "cert.pem", tmp_path / "key.pem"
    cert_path.write_bytes(pem)
    key_path.write_bytes(
        key.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8,
            serialization.NoEncryption(),
        )
    )
    server_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    server_context.load_cert_chain(cert_path, key_path)
    client_context = ssl.create_default_context(cadata=pem.decode())

    async def handshake() -> None:
        await TLSStream.wrap(
            MemoryTLSServer(server_context),
            hostname=hostname,
            ssl_context=client_context,
            server_side=False,
        )

    if accepted:
        anyio.run(handshake)
    else:
        with pytest.raises(ssl.SSLCertVerificationError, match="Hostname mismatch"):
            anyio.run(handshake)
