# Remote product image policy

Receipt HTML and extraction responses are untrusted. `Item.imageURL` is stored as source data, but
the app must never hand that string directly to `AsyncImage`, `URLSession`, or a web view.

All product-image requests go through `RemoteImagePolicy.production` and `RemoteImageLoader`:

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

To add a host, first capture evidence from a real retailer receipt, confirm that the domain is
owned or controlled by the retailer or its image CDN, review redirect behaviour, and add hostile
boundary tests. Do not add a host merely because model output contains it. The allowlist is
intentionally expected to omit some retailers; a placeholder is the safe default.
