import Testing

@testable import Wardrobe

struct ConnectedFeaturePresentationTests {
    @Test func arbitraryPipelineDiagnosticsAreNotShownToTheUser() {
        let diagnostic = "HTTP 500: token=secret; SQLite error at /private/path"

        let message = ReceiptImportPresentation.failureMessage(for: diagnostic)

        #expect(message == "Receipt import couldn’t finish. Check your connection and try again. Your existing wardrobe is unchanged.")
        #expect(!message.contains("secret"))
        #expect(!message.contains("SQLite"))
        #expect(!message.contains("500"))
    }

    @Test func cancellationHasAUsefulRestartMessage() {
        #expect(
            ReceiptImportPresentation.failureMessage(for: "Receipt sync was cancelled.")
                == "Receipt import stopped. You can restart it whenever you’re ready."
        )
    }

    @Test func actionableConsentFailureKeepsItsSpecificInstruction() {
        let message = "Review data use and allow receipt analysis before syncing Gmail."
        #expect(ReceiptImportPresentation.failureMessage(for: message) == message)
    }
}
