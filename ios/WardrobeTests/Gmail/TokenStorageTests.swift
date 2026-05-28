import Foundation
import Testing

@testable import Wardrobe

/// Each test uses a unique service name so they don't collide with other test runs in the
/// simulator's keychain. The trailing `cleanup` block removes every account it touched.
struct TokenStorageTests {

    private func makeStorage() -> TokenStorage {
        TokenStorage(service: "wardrobe.tests.\(UUID().uuidString)")
    }

    @Test func roundTripsAValue() throws {
        let storage = makeStorage()
        defer { try? storage.remove("access") }

        try storage.set("token-abc", for: "access")
        #expect(try storage.get("access") == "token-abc")
    }

    @Test func overwritesExistingValue() throws {
        let storage = makeStorage()
        defer { try? storage.remove("access") }

        try storage.set("token-old", for: "access")
        try storage.set("token-new", for: "access")
        #expect(try storage.get("access") == "token-new")
    }

    @Test func missingAccountReturnsNil() throws {
        let storage = makeStorage()
        #expect(try storage.get("never-written") == nil)
    }

    @Test func removeMakesValueDisappear() throws {
        let storage = makeStorage()
        try storage.set("token", for: "access")
        try storage.remove("access")
        #expect(try storage.get("access") == nil)
    }

    @Test func removeOnMissingAccountIsSilent() throws {
        let storage = makeStorage()
        // No prior write; should not throw.
        try storage.remove("never-written")
    }

    @Test func differentAccountsAreIndependent() throws {
        let storage = makeStorage()
        defer {
            try? storage.remove("access")
            try? storage.remove("refresh")
        }

        try storage.set("a-1", for: "access")
        try storage.set("r-1", for: "refresh")
        #expect(try storage.get("access") == "a-1")
        #expect(try storage.get("refresh") == "r-1")

        try storage.remove("access")
        #expect(try storage.get("access") == nil)
        #expect(try storage.get("refresh") == "r-1")
    }
}
