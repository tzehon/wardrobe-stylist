import Foundation
import Testing

@testable import Wardrobe

struct TokenStorageTests {
    private func makeStorage() -> TokenStorage {
        TokenStorage(service: "wardrobe.tests.\(UUID().uuidString)")
    }

    @Test func roundTripsAndOverwritesDeviceOnlyValue() throws {
        let storage = makeStorage()
        defer { try? storage.remove("installation-key") }

        try storage.set("first", for: "installation-key")
        #expect(try storage.get("installation-key") == "first")
        try storage.set("second", for: "installation-key")
        #expect(try storage.get("installation-key") == "second")
    }

    @Test func missingAndRemovedValuesReturnNil() throws {
        let storage = makeStorage()
        #expect(try storage.get("installation-key") == nil)
        try storage.set("value", for: "installation-key")
        try storage.remove("installation-key")
        #expect(try storage.get("installation-key") == nil)
        try storage.remove("installation-key")
    }
}
