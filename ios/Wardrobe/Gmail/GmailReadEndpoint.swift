import Foundation

/// The complete, exhaustive set of Gmail REST calls this app is allowed to make.
///
/// READ-ONLY BY CONSTRUCTION: every case maps to an HTTP `GET` against a read endpoint.
/// There is intentionally **no** case for any mutating operation (send / insert / import /
/// modify / batchModify / trash / untrash / delete / batchDelete / drafts / label writes /
/// settings writes). All Gmail networking in the app MUST be expressed through this enum,
/// which makes a write request unrepresentable. `GmailReadOnlyGuardTests` enforces this.
enum GmailReadEndpoint: Equatable {
    private static let base = "https://gmail.googleapis.com/gmail/v1/users/me"

    case getProfile
    case listMessages(query: String, includeSpamTrash: Bool, pageToken: String?)
    case getMessage(id: String)
    case getAttachment(messageId: String, attachmentId: String)
    case listThreads(query: String, pageToken: String?)
    case getThread(id: String)
    case listHistory(startHistoryId: String, pageToken: String?)
    case listLabels
    case getLabel(id: String)

    /// Read-only: there is only ever one HTTP method.
    var httpMethod: String { "GET" }

    var path: String {
        switch self {
        case .getProfile:
            return "/profile"
        case .listMessages:
            return "/messages"
        case .getMessage(let id):
            return "/messages/\(id)"
        case .getAttachment(let messageId, let attachmentId):
            return "/messages/\(messageId)/attachments/\(attachmentId)"
        case .listThreads:
            return "/threads"
        case .getThread(let id):
            return "/threads/\(id)"
        case .listHistory:
            return "/history"
        case .listLabels:
            return "/labels"
        case .getLabel(let id):
            return "/labels/\(id)"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .listMessages(let query, let includeSpamTrash, let pageToken):
            var items = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "includeSpamTrash", value: includeSpamTrash ? "true" : "false"),
            ]
            if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            return items
        case .getMessage:
            return [URLQueryItem(name: "format", value: "full")]
        case .listThreads(let query, let pageToken):
            var items = [URLQueryItem(name: "q", value: query)]
            if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            return items
        case .listHistory(let startHistoryId, let pageToken):
            var items = [URLQueryItem(name: "startHistoryId", value: startHistoryId)]
            if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            return items
        default:
            return []
        }
    }

    /// Fully-formed request URL.
    var url: URL {
        var components = URLComponents(string: Self.base + path)!
        let items = queryItems
        components.queryItems = items.isEmpty ? nil : items
        return components.url!
    }

    /// Representative instances of every case, for the read-only guard test to enumerate.
    static var allShapesForTesting: [GmailReadEndpoint] {
        [
            .getProfile,
            .listMessages(query: "receipt", includeSpamTrash: true, pageToken: nil),
            .getMessage(id: "msg123"),
            .getAttachment(messageId: "msg123", attachmentId: "att1"),
            .listThreads(query: "receipt", pageToken: nil),
            .getThread(id: "thr1"),
            .listHistory(startHistoryId: "98765", pageToken: nil),
            .listLabels,
            .getLabel(id: "Label_1"),
        ]
    }
}
