import Foundation
import Testing

@testable import Wardrobe

struct RemovedCapabilitiesReleaseGuardTests {
    @Test func shippedSourceAndConfigurationExcludeRemovedCapabilities() throws {
        let iosRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let candidates = [
            iosRoot.appending(path: "Wardrobe"),
            iosRoot.appending(path: "project.yml"),
            iosRoot.appending(path: "Config.xcconfig"),
            iosRoot.appending(path: "Distribution.xcconfig.example"),
            iosRoot.appending(path: "Secrets.xcconfig.example"),
        ]
        let forbidden = [
            "Google" + "SignIn",
            "G" + "IDClientID",
            "GOOGLE" + "_CLIENT_ID",
            "gmail" + ".readonly",
            "gmail" + ".googleapis.com",
            "G" + "mail",
            "/" + "extract",
            "receipt" + "Sync",
            "BGTaskScheduler" + "PermittedIdentifiers",
        ]

        for candidate in candidates {
            for file in try textFiles(at: candidate) {
                let contents = try String(contentsOf: file, encoding: .utf8)
                for token in forbidden {
                    #expect(
                        !contents.localizedCaseInsensitiveContains(token),
                        "Removed capability token found in \(file.path): \(token)"
                    )
                }
            }
        }
    }

    @Test func generatedProjectContainsNoThirdPartySignInPackage() throws {
        let iosRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let project = iosRoot.appending(path: "Wardrobe.xcodeproj/project.pbxproj")
        guard FileManager.default.fileExists(atPath: project.path) else { return }
        let contents = try String(contentsOf: project, encoding: .utf8)
        #expect(!contents.contains("Google" + "SignIn"))
        #expect(!contents.contains("GTM" + "AppAuth"))
        #expect(!contents.contains("App" + "Auth"))
    }

    private func textFiles(at url: URL) throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return []
        }
        guard isDirectory.boolValue else { return [url] }
        let allowedExtensions = Set(["swift", "plist", "yml", "xcconfig"])
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var result: [URL] = []
        while let file = enumerator?.nextObject() as? URL {
            guard allowedExtensions.contains(file.pathExtension) else { continue }
            result.append(file)
        }
        return result
    }
}
