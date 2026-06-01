import Foundation
import Testing

@testable import Wardrobe

struct BackendConfigTests {

    @Test func loadsBaseURLAndDeviceTokenFromInfoPlist() throws {
        let (url, token) = try BackendConfig.load(infoPlist: [
            "BackendBaseURL": "http://192.168.88.10:8000",
            "BackendDeviceToken": "secret-token",
        ])
        #expect(url.absoluteString == "http://192.168.88.10:8000")
        #expect(token == "secret-token")
    }

    @Test func trimsWhitespaceAroundValues() throws {
        let (url, token) = try BackendConfig.load(infoPlist: [
            "BackendBaseURL": "  http://x.example  ",
            "BackendDeviceToken": "  t  ",
        ])
        #expect(url.absoluteString == "http://x.example")
        #expect(token == "t")
    }

    @Test func throwsWhenURLMissing() {
        do {
            _ = try BackendConfig.load(infoPlist: ["BackendDeviceToken": "t"])
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
                "BackendDeviceToken": "t",
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
                "BackendDeviceToken": "t",
            ])
            Issue.record("Expected invalidURL")
        } catch BackendConfig.LoadError.invalidURL {
            // expected
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }

    @Test func throwsWhenTokenMissing() {
        do {
            _ = try BackendConfig.load(infoPlist: [
                "BackendBaseURL": "http://x.example",
            ])
            Issue.record("Expected missingValue")
        } catch BackendConfig.LoadError.missingValue(let key) {
            #expect(key == "BACKEND_DEVICE_TOKEN")
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }

    @Test func throwsWhenTokenEmpty() {
        do {
            _ = try BackendConfig.load(infoPlist: [
                "BackendBaseURL": "http://x.example",
                "BackendDeviceToken": "   ",
            ])
            Issue.record("Expected missingValue")
        } catch BackendConfig.LoadError.missingValue(let key) {
            #expect(key == "BACKEND_DEVICE_TOKEN")
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }
}
