import Foundation
import Testing

@testable import Wardrobe

struct BackendConfigTests {

    @Test func loadsBaseURLFromInfoPlistWithoutAClientSecret() throws {
        // 192.0.2.x is RFC 5737 TEST-NET-1 — reserved for documentation/examples.
        let url = try BackendConfig.load(infoPlist: [
            "BackendBaseURL": "http://192.0.2.1:8000",
        ])
        #expect(url.absoluteString == "http://192.0.2.1:8000")
    }

    @Test func trimsWhitespaceAroundURL() throws {
        let url = try BackendConfig.load(infoPlist: [
            "BackendBaseURL": "  http://x.example  ",
        ])
        #expect(url.absoluteString == "http://x.example")
    }

    @Test func throwsWhenURLMissing() {
        do {
            _ = try BackendConfig.load(infoPlist: [:])
            Issue.record("Expected missingValue")
        } catch BackendConfig.LoadError.missingValue(let key) {
            #expect(key == "BACKEND_BASE_URL")
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }

    @Test func throwsWhenURLEmpty() {
        do {
            _ = try BackendConfig.load(infoPlist: [
                "BackendBaseURL": "",
            ])
            Issue.record("Expected missingValue")
        } catch BackendConfig.LoadError.missingValue(let key) {
            #expect(key == "BACKEND_BASE_URL")
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }

    @Test func throwsWhenURLInvalid() {
        do {
            _ = try BackendConfig.load(infoPlist: [
                "BackendBaseURL": "not a url at all",
            ])
            Issue.record("Expected invalidURL")
        } catch BackendConfig.LoadError.invalidURL {
            // expected
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }

    @Test func ignoresLegacyDeviceTokenIfPresentInInjectedDictionary() throws {
        let url = try BackendConfig.load(infoPlist: [
            "BackendBaseURL": "https://x.example",
            "BackendDeviceToken": "must-not-be-read",
        ])
        #expect(url.absoluteString == "https://x.example")
    }
}
