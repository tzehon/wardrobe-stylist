import Foundation

/// Hand-rolled JSON-LD email fixtures based on shapes Shopify, WooCommerce,
/// and other order-confirmation emails actually emit. Kept inline so the tests
/// stay self-contained.
enum JSONLDFixtures {

    /// Shopify-style Order with one acceptedOffer wrapping an itemOffered Product.
    /// Price is on the Offer, brand is a nested {@type: Brand, name: ...}.
    static let shopifyOrderSingleItemHTML = #"""
    <html><body>
      Receipt body in HTML.
      <script type="application/ld+json">
      {
        "@context": "https://schema.org",
        "@type": "Order",
        "orderNumber": "1001",
        "merchant": {"@type": "Organization", "name": "Everlane"},
        "acceptedOffer": [{
          "@type": "Offer",
          "price": "78.00",
          "priceCurrency": "USD",
          "itemOffered": {
            "@type": "Product",
            "name": "Classic Oxford Shirt",
            "brand": {"@type": "Brand", "name": "Everlane"},
            "image": "https://cdn.shopify.com/p/shirt-white.jpg"
          }
        }]
      }
      </script>
    </body></html>
    """#

    /// Shopify-style Order with two acceptedOffer items, mixed brand shapes
    /// (one nested, one bare string).
    static let shopifyOrderMultipleItemsHTML = #"""
    <html><body>
      <script type='application/ld+json'>
      {
        "@context": "https://schema.org",
        "@type": "Order",
        "acceptedOffer": [
          {
            "@type": "Offer",
            "price": 78.0,
            "priceCurrency": "USD",
            "itemOffered": {
              "@type": "Product",
              "name": "Classic Oxford Shirt",
              "brand": {"name": "Everlane"},
              "image": ["https://cdn.example/shirt-1.jpg", "https://cdn.example/shirt-2.jpg"]
            }
          },
          {
            "@type": "Offer",
            "price": 128.0,
            "priceCurrency": "USD",
            "itemOffered": {
              "@type": "Product",
              "name": "Wool Trousers",
              "brand": "Everlane"
            }
          }
        ]
      }
      </script>
    </body></html>
    """#

    /// A bare Product node with `offers` rather than the Order wrapper.
    /// Image is an `ImageObject` (object with `url`), price is a stringy "$24.99".
    static let bareProductHTML = #"""
    <html><body>
      <script type="application/ld+json">
      {
        "@context": "https://schema.org",
        "@type": "Product",
        "name": "Gold hoop earrings",
        "brand": "Mejuri",
        "image": {"@type": "ImageObject", "url": "https://cdn.example/hoops.jpg"},
        "offers": {
          "@type": "Offer",
          "price": "$24.99",
          "priceCurrency": "USD"
        }
      }
      </script>
    </body></html>
    """#

    /// A `@graph` wrapper containing two top-level items (an Organization, a
    /// Product). Only the Product should be extracted.
    static let graphWrapperHTML = #"""
    <html><body>
      <script type="application/ld+json">
      {
        "@context": "https://schema.org",
        "@graph": [
          {"@type": "Organization", "name": "Mejuri"},
          {
            "@type": "Product",
            "name": "Suede crossbody",
            "brand": "Polène",
            "offers": {
              "priceSpecification": {"price": 350, "priceCurrency": "EUR"}
            }
          }
        ]
      }
      </script>
    </body></html>
    """#

    /// Multiple JSON-LD blocks in the same email (one Order, one BreadcrumbList).
    /// The BreadcrumbList has no Products; the Order has one.
    static let multipleBlocksHTML = #"""
    <html><body>
      <script type="application/ld+json">
      {"@type": "BreadcrumbList", "itemListElement": [{"@type": "ListItem", "name": "Home"}]}
      </script>
      <script type="application/ld+json">
      {
        "@context": "https://schema.org",
        "@type": "Order",
        "acceptedOffer": {
          "@type": "Offer",
          "price": 49.50,
          "priceCurrency": "GBP",
          "itemOffered": {
            "@type": "Product",
            "name": "Linen tee"
          }
        }
      }
      </script>
    </body></html>
    """#

    /// Malformed JSON inside the script tag — should be skipped without throwing.
    static let malformedJSONHTML = #"""
    <html><body>
      <script type="application/ld+json">{ "@type": "Product", "name": "Broken</script>
    </body></html>
    """#

    /// Plain HTML with no JSON-LD at all.
    static let noJSONLDHTML = #"""
    <html><body><p>Just a plain text email.</p></body></html>
    """#

    /// Duplicate product across the Order wrapper and a standalone Product node.
    /// Dedupe should fold them into a single SchemaOrgItem.
    static let duplicateProductHTML = #"""
    <html><body>
      <script type="application/ld+json">
      [
        {
          "@type": "Order",
          "acceptedOffer": {
            "@type": "Offer",
            "price": 50,
            "priceCurrency": "USD",
            "itemOffered": {"@type": "Product", "name": "Bandana", "brand": "Acme"}
          }
        },
        {"@type": "Product", "name": "Bandana", "brand": "Acme"}
      ]
      </script>
    </body></html>
    """#
}
