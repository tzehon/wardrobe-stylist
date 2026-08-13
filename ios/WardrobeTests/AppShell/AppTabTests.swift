import Testing

@testable import Wardrobe

struct AppTabTests {
    @Test func shellExposesStableLocalDestinations() {
        #expect(AppTab.allCases == [.today, .wardrobe, .settings])
        #expect(AppTab.allCases.map(\.title) == ["Today", "Wardrobe", "Settings"])
        #expect(AppTab.allCases.map(\.accessibilityIdentifier) == [
            "tab.today",
            "tab.wardrobe",
            "tab.settings",
        ])
        #expect(Set(AppTab.allCases.map(\.accessibilityIdentifier)).count == AppTab.allCases.count)
    }

    @Test func versionPresentationIncludesBuildWhenAvailable() {
        #expect(AppVersionInfo(version: "1.2.3", build: "45").displayText == "1.2.3 (45)")
        #expect(AppVersionInfo(version: "1.2.3", build: "").displayText == "1.2.3")
    }
}
