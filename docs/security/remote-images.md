# Historical remote product image policy

> **Historical/deferred — not public-v1 behavior.** The approved Gmail-free v1 creates wardrobe
> items from manual entry or user-selected photos and contains no receipt extraction or remote
> product-image loader. This document records the defense-in-depth policy used by the removed
> receipt-import implementation. Reintroducing any remote-image source requires a separately
> approved product, privacy, security, and release review.

In the earlier implementation, receipt HTML and extraction responses were untrusted.
`Item.imageURL` was stored as source data, but the app never handed that string directly to
`AsyncImage`, `URLSession`, or a web view. All product-image requests went through
`RemoteImagePolicy.production` and `RemoteImageLoader`:

- URLs must be canonical HTTPS URLs without credentials, fragments, alternate ports, address
  literals, local names, control characters, or internationalized-domain lookalikes.
- The destination host must be an exact match for, or a subdomain of, the reviewed CDN list in
  `RemoteImagePolicy.swift`. Suffix-looking hostnames outside that boundary are rejected.
- Redirects are not followed because their new destination has not passed the source policy.
- Responses must be successful supported still-image MIME types. GIF and SVG are rejected.
- Download streaming stops at 5 MiB. ImageIO reads metadata without eager decoding, rejects
  animated or excessive-dimension sources, and produces a thumbnail no larger than 1,200 pixels.
- Decoded thumbnails use a memory-only cache capped by item count and decoded-byte cost. Failed or
  rejected loads show an accessible category placeholder.

If this capability is separately approved for a future release, adding a host first requires
evidence from a real retailer source, confirmation that the domain is owned or controlled by the
retailer or its image CDN, review of redirect behaviour, and hostile-boundary tests. Never add a
host merely because model output contains it. An intentionally incomplete allowlist and a local
placeholder remain the safe defaults.
