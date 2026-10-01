import Foundation
import Testing

@testable import Wardrobe

struct CommerceUsageTests {
    // Resolve the checked-in shared corpus from this source path, as the test
    // executes on the same Mac that built it. No production resource is added.
    private func fixtures(_ group: String) throws -> [[String: Any]] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("shared/fixtures/commerce-usage.json"))
        let corpus = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(corpus[group] as? [[String: Any]])
    }

    @Test func sharedValidSnapshotsDecode() throws {
        for fixture in try fixtures("valid") {
            let value = try #require(fixture["value"])
            let data = try JSONSerialization.data(withJSONObject: value)
            let snapshot = try JSONDecoder().decode(CommerceUsage.self, from: data)
            #expect(snapshot.remaining == snapshot.allowance - snapshot.consumed - snapshot.reserved)
            #expect(snapshot.consumed == snapshot.successfulGenerations - snapshot.deliveryCreditsUsed)
        }
    }

    @Test func sharedMalformedAndInconsistentSnapshotsFailClosed() throws {
        for group in ["invalid_structure", "invalid_semantics"] {
            for fixture in try fixtures(group) {
                let value = try #require(fixture["value"])
                let data = try JSONSerialization.data(withJSONObject: value)
                #expect(throws: DecodingError.self) {
                    try JSONDecoder().decode(CommerceUsage.self, from: data)
                }
            }
        }
    }
}
