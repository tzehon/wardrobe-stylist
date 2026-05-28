import Foundation

// MARK: - Profile

/// `users.getProfile` response.
struct GmailProfile: Codable, Equatable, Sendable {
    let emailAddress: String
    let messagesTotal: Int
    let threadsTotal: Int
    let historyId: String
}

// MARK: - Message list

/// `users.messages.list` response.
struct GmailMessageList: Codable, Equatable, Sendable {
    let messages: [MessageRef]?
    let nextPageToken: String?
    let resultSizeEstimate: Int?

    struct MessageRef: Codable, Equatable, Sendable {
        let id: String
        let threadId: String
    }
}

// MARK: - Message

/// `users.messages.get` (format=full) response.
struct GmailMessage: Codable, Equatable, Sendable {
    let id: String
    let threadId: String
    let labelIds: [String]?
    let snippet: String?
    let historyId: String?
    let internalDate: String?            // millis since epoch as string
    let sizeEstimate: Int?
    let payload: GmailMessagePart?
}

/// Recursive MIME node. Leaf parts carry `body.data` (small bodies) or
/// `body.attachmentId` (larger payloads fetched via `attachments.get`).
struct GmailMessagePart: Codable, Equatable, Sendable {
    let partId: String?
    let mimeType: String?
    let filename: String?
    let headers: [GmailHeader]?
    let body: GmailMessageBody?
    let parts: [GmailMessagePart]?
}

struct GmailHeader: Codable, Equatable, Sendable {
    let name: String
    let value: String
}

struct GmailMessageBody: Codable, Equatable, Sendable {
    let attachmentId: String?
    let size: Int?
    let data: String?                    // base64url-encoded (when inline)
}

// MARK: - Attachment

/// `users.messages.attachments.get` response.
struct GmailAttachment: Codable, Equatable, Sendable {
    let attachmentId: String?
    let size: Int
    let data: String                     // base64url-encoded
}

// MARK: - History (incremental sync)

/// `users.history.list` response — used to cheaply fetch what changed since a known
/// `historyId`, instead of re-listing the whole mailbox.
struct GmailHistory: Codable, Equatable, Sendable {
    let history: [Record]?
    let nextPageToken: String?
    let historyId: String

    struct Record: Codable, Equatable, Sendable {
        let id: String
        let messages: [GmailMessageList.MessageRef]?
        let messagesAdded: [MessageEnvelope]?
        let labelsAdded: [LabelChange]?
        let labelsRemoved: [LabelChange]?
    }

    struct MessageEnvelope: Codable, Equatable, Sendable {
        let message: GmailMessageList.MessageRef
    }

    struct LabelChange: Codable, Equatable, Sendable {
        let message: GmailMessageList.MessageRef
        let labelIds: [String]?
    }
}
