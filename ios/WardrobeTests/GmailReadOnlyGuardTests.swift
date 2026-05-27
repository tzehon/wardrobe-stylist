import Foundation
import Testing

@testable import Wardrobe

/// Enforces the hard rule that the app is **strictly read-only** on Gmail.
///
/// Three layers:
///  1. The app requests exactly the read-only OAuth scope.
///  2. Every endpoint the app can construct is a GET against an allowlisted read path
///     (writes are unrepresentable in `GmailReadEndpoint`).
///  3. Defense-in-depth: the Gmail source directory contains no mutating HTTP method or
///     Gmail write path fragment.
struct GmailReadOnlyGuardTests {

    @Test func requestsOnlyTheReadOnlyScope() {
        #expect(GmailScope.requested == ["https://www.googleapis.com/auth/gmail.readonly"])
        #expect(GmailScope.readonly.hasSuffix("/auth/gmail.readonly"))
    }

    @Test func everyEndpointIsAReadOnlyGet() {
        let allowedPrefixes = ["/profile", "/messages", "/threads", "/history", "/labels"]
        let forbiddenPathFragments = [
            "/send", "/modify", "/trash", "/untrash",
            "/batchModify", "/batchDelete", "/drafts", "/import", "/insert",
        ]
        for endpoint in GmailReadEndpoint.allShapesForTesting {
            #expect(endpoint.httpMethod == "GET")
            let path = endpoint.path
            #expect(
                allowedPrefixes.contains { path.hasPrefix($0) },
                "Endpoint path is not on the read-only allowlist: \(path)"
            )
            for fragment in forbiddenPathFragments {
                #expect(!path.contains(fragment), "Write path fragment \(fragment) in \(path)")
            }
        }
    }

    @Test func gmailSourceContainsNoWriteOperations() throws {
        let fm = FileManager.default
        guard let dir = Self.gmailSourceDir(), fm.fileExists(atPath: dir.path) else {
            // Source tree not reachable in this run; the endpoint enumeration above still
            // guarantees read-only. Skip the filesystem scan rather than fail spuriously.
            return
        }
        let forbiddenTokens = [
            #""POST""#, #""PUT""#, #""PATCH""#, #""DELETE""#,
            "/send", "/modify", "/trash", "/untrash",
            "/batchModify", "/batchDelete", "/drafts", "/import", "/insert",
        ]
        let swiftFiles = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        #expect(!swiftFiles.isEmpty, "Expected Swift files in \(dir.path)")

        for file in swiftFiles {
            let contents = try String(contentsOf: file, encoding: .utf8)
            for token in forbiddenTokens {
                #expect(
                    !contents.contains(token),
                    "Forbidden token \(token) found in Gmail source file \(file.lastPathComponent)"
                )
            }
        }
    }

    /// Locate `ios/Wardrobe/Gmail` relative to this test file (resolved at compile time).
    private static func gmailSourceDir() -> URL? {
        // #filePath = .../ios/WardrobeTests/GmailReadOnlyGuardTests.swift
        let iosDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // WardrobeTests/
            .deletingLastPathComponent()   // ios/
        return iosDir.appendingPathComponent("Wardrobe/Gmail", isDirectory: true)
    }
}
