import Foundation
import Testing

@testable import Wardrobe

struct JSONLDExtractorTests {

    @Test func extractsShopifyOrderSingleItem() {
        let items = JSONLDExtractor.extract(fromHTML: JSONLDFixtures.shopifyOrderSingleItemHTML)
        #expect(items.count == 1)
        let item = items[0]
        #expect(item.name == "Classic Oxford Shirt")
        #expect(item.brand == "Everlane")
        #expect(item.price == 78.0)
        #expect(item.currency == "USD")
        #expect(item.imageURL == "https://cdn.shopify.com/p/shirt-white.jpg")
    }

    @Test func extractsMultipleItemsWithMixedBrandShapes() {
        let items = JSONLDExtractor.extract(
            fromHTML: JSONLDFixtures.shopifyOrderMultipleItemsHTML
        )
        #expect(items.count == 2)
        // First item — brand as nested object, image as array (first wins).
        #expect(items[0].name == "Classic Oxford Shirt")
        #expect(items[0].brand == "Everlane")
        #expect(items[0].imageURL == "https://cdn.example/shirt-1.jpg")
        #expect(items[0].price == 78.0)
        // Second item — brand as bare string, no image.
        #expect(items[1].name == "Wool Trousers")
        #expect(items[1].brand == "Everlane")
        #expect(items[1].imageURL == nil)
        #expect(items[1].price == 128.0)
    }

    @Test func extractsBareProductWithStringPrice() {
        let items = JSONLDExtractor.extract(fromHTML: JSONLDFixtures.bareProductHTML)
        #expect(items.count == 1)
        let item = items[0]
        #expect(item.name == "Gold hoop earrings")
        #expect(item.brand == "Mejuri")
        #expect(item.imageURL == "https://cdn.example/hoops.jpg")
        // "$24.99" string → parsed to 24.99
        #expect(item.price == 24.99)
        #expect(item.currency == "USD")
    }

    @Test func unwrapsGraphAndSkipsNonProductNodes() {
        let items = JSONLDExtractor.extract(fromHTML: JSONLDFixtures.graphWrapperHTML)
        #expect(items.count == 1)
        let item = items[0]
        #expect(item.name == "Suede crossbody")
        #expect(item.brand == "Polène")
        // Price came from offers.priceSpecification.
        #expect(item.price == 350)
        #expect(item.currency == "EUR")
    }

    @Test func handlesMultipleJSONLDBlocks() {
        let items = JSONLDExtractor.extract(fromHTML: JSONLDFixtures.multipleBlocksHTML)
        #expect(items.count == 1)
        #expect(items[0].name == "Linen tee")
        #expect(items[0].currency == "GBP")
        #expect(items[0].price == 49.50)
    }

    @Test func dedupesIdenticalProductAcrossNodes() {
        let items = JSONLDExtractor.extract(fromHTML: JSONLDFixtures.duplicateProductHTML)
        #expect(items.count == 1)
        #expect(items[0].name == "Bandana")
        // The price came from the Offer wrapper (encountered first during walk).
        #expect(items[0].price == 50)
    }

    @Test func returnsEmptyForMalformedJSON() {
        let items = JSONLDExtractor.extract(fromHTML: JSONLDFixtures.malformedJSONHTML)
        #expect(items.isEmpty)
    }

    @Test func returnsEmptyWhenNoJSONLD() {
        let items = JSONLDExtractor.extract(fromHTML: JSONLDFixtures.noJSONLDHTML)
        #expect(items.isEmpty)
    }

    @Test func returnsEmptyForEmptyHTML() {
        #expect(JSONLDExtractor.extract(fromHTML: "").isEmpty)
    }

    @Test func toleratesSingleQuotedTypeAttribute() {
        // The Shopify multi-item fixture uses single quotes around type — ensure
        // the block-finder regex still matches.
        let items = JSONLDExtractor.extract(
            fromHTML: JSONLDFixtures.shopifyOrderMultipleItemsHTML
        )
        #expect(items.count == 2)
    }
}
