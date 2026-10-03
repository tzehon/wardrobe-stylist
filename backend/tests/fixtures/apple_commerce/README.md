# Apple commerce fixture provenance

Retrieved 3 October 2026 over the configured HTTPS proxy with TLS verification enabled.
These are public test inputs, never runtime trust configuration or customer evidence.

| Fixture | Official source | DER SHA-256 |
| --- | --- | --- |
| AppleIncRootCertificate.cer | https://www.apple.com/appleca/AppleIncRootCertificate.cer | b0b1730ecbc7ff4505142c49f1295e6eda6bcaed7e2c68c5be91b5a11001f024 |
| AppleRootCA-G2.cer | https://www.apple.com/certificateauthority/AppleRootCA-G2.cer | c2b9b042dd57830e7d117dac55ac8ae19407d38e41d88f3215bc3a890444a050 |
| AppleRootCA-G3.cer | https://www.apple.com/certificateauthority/AppleRootCA-G3.cer | 63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179 |

The URLs come from [Apple PKI](https://www.apple.com/certificateauthority/), as directed by the
[SDK README](https://github.com/apple/app-store-server-library-python/blob/1da04603e77b7da5b6a160d4ef8410ba2d2b70d4/README.md).
Root identity, CA constraints, self-signatures and validity at acquisition are checked offline.
These checks do not prove receipt compatibility, current revocation status or device ownership.

`upstream_mock_transaction.jws` is an unchanged copy of
[Apple's transactionInfo mock](https://github.com/apple/app-store-server-library-python/blob/1da04603e77b7da5b6a160d4ef8410ba2d2b70d4/tests/resources/mock_signed_data/transactionInfo),
commit `1da04603e77b7da5b6a160d4ef8410ba2d2b70d4`, under the accompanying `UPSTREAM_LICENSE.txt`.
Its chain uses Apple's **test CA**, not Apple's public production roots. The test deliberately
requires rejection. No test signing key or real purchase receipt was copied.
