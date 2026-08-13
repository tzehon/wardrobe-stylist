import Foundation

/// Keeps implementation diagnostics at the logging/testing boundary instead
/// of presenting SDK, transport, database, or backend details to App Store
/// users. Known actionable states retain their specific guidance.
enum ReceiptImportPresentation {
    static let configurationUnavailable =
        "Receipt import isn’t available in this build. Please update the app and try again."

    static func failureMessage(for pipelineMessage: String) -> String {
        switch pipelineMessage {
        case "Receipt sync was cancelled.":
            "Receipt import stopped. You can restart it whenever you’re ready."
        case "Review data use and allow receipt analysis before syncing Gmail.":
            pipelineMessage
        case "Background receipt sync is turned off.":
            pipelineMessage
        case "Privacy preferences are unavailable. Receipt sync was not started.":
            "Your privacy choices couldn’t be loaded, so receipt import stayed off. Try again from Settings."
        case "Receipt sync is not allowed by the current privacy settings.":
            "Your current privacy choices keep receipt import off. Review them in Settings before trying again."
        default:
            "Receipt import couldn’t finish. Check your connection and try again. Your existing wardrobe is unchanged."
        }
    }
}
