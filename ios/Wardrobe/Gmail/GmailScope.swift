import Foundation

/// OAuth scopes. The app requests exactly one — and it is read-only.
///
/// `gmail.readonly` permits reading message bodies and attachments but **cannot** modify
/// the mailbox in any way. We never request a broader or write-capable scope.
enum GmailScope {
    static let readonly = "https://www.googleapis.com/auth/gmail.readonly"

    /// The exact set of scopes requested at sign-in.
    static let requested: [String] = [readonly]
}
