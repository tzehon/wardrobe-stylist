import Testing

@testable import Wardrobe

struct StylingOccasionTests {
    @Test func requestValueTrimsAndAppliesTheBackendLimit() {
        let oversized = "  \(String(repeating: "x", count: 200))  "

        let result = StylingOccasion.requestValue(oversized)

        #expect(result == String(repeating: "x", count: StylingOccasion.maximumLength))
        #expect(StylingOccasion.requestValue(" \n\t ") == nil)
    }

    @Test func limitCountsUnicodeCodePointsWithoutSplittingACharacter() {
        let family = "👨‍👩‍👧‍👦"
        let oversized = String(repeating: family, count: 30)

        let result = StylingOccasion.limited(oversized)

        #expect(result.unicodeScalars.count <= StylingOccasion.maximumLength)
        #expect(result.allSatisfy { String($0) == family })
        #expect(result.count == 18)
    }
}
