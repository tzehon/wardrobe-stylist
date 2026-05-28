import Foundation
import Testing

@testable import Wardrobe

struct Base64URLTests {

    @Test func decodesStandardAlphabetWithPadding() throws {
        let data = try #require(Base64URL.decode("SGVsbG8sIHdvcmxkIQ=="))
        #expect(String(data: data, encoding: .utf8) == "Hello, world!")
    }

    @Test func decodesUnpaddedInput() throws {
        let data = try #require(Base64URL.decode("SGVsbG8sIHdvcmxkIQ"))
        #expect(String(data: data, encoding: .utf8) == "Hello, world!")
    }

    @Test func decodesURLSafeAlphabet() throws {
        // Bytes 0xFB 0xFF 0xBF — chosen to produce '+' and '/' in standard base64,
        // which become '-' and '_' in base64url. We verify the URL-safe form decodes too.
        let urlSafe = "-_-_"
        let data = try #require(Base64URL.decode(urlSafe))
        #expect(data.count == 3)

        // Round-trip via the encoder.
        let encoded = Base64URL.encode(data)
        #expect(encoded == urlSafe)
    }

    @Test func returnsNilForMalformedInput() {
        #expect(Base64URL.decode("!!!not-base64!!!") == nil)
    }

    @Test func encodeProducesNoPaddingAndNoUnsafeChars() {
        let encoded = Base64URL.encode(Data([0xFB, 0xFF, 0xBF]))
        #expect(!encoded.contains("="))
        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("/"))
    }
}
