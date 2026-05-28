import Foundation

/// JSON fixtures used by the Gmail tests. Kept inline (rather than as bundled resources)
/// so the tests stay self-contained and easy to read.
enum GmailFixtures {

    static let profileJSON = #"""
    {
      "emailAddress": "user@example.com",
      "messagesTotal": 12345,
      "threadsTotal": 6789,
      "historyId": "987654"
    }
    """#

    static let messageListPage1JSON = #"""
    {
      "messages": [
        {"id": "m1", "threadId": "t1"},
        {"id": "m2", "threadId": "t1"}
      ],
      "nextPageToken": "PT_2",
      "resultSizeEstimate": 250
    }
    """#

    static let messageListPage2JSON = #"""
    {
      "messages": [
        {"id": "m3", "threadId": "t2"}
      ],
      "resultSizeEstimate": 1
    }
    """#

    /// A multipart message: alternative(text/plain, text/html) + a PDF attachment leaf.
    /// `text/plain` body decodes to "Hello, world!" via base64url.
    static let messageMultipartJSON = #"""
    {
      "id": "m1",
      "threadId": "t1",
      "labelIds": ["INBOX", "CATEGORY_PROMOTIONS"],
      "snippet": "Your order is confirmed",
      "historyId": "55555",
      "internalDate": "1716745200000",
      "sizeEstimate": 23456,
      "payload": {
        "partId": "",
        "mimeType": "multipart/mixed",
        "filename": "",
        "headers": [
          {"name": "From",    "value": "orders@retailer.com"},
          {"name": "Subject", "value": "Order #98765 confirmed"}
        ],
        "parts": [
          {
            "partId": "0",
            "mimeType": "multipart/alternative",
            "filename": "",
            "parts": [
              {
                "partId": "0.0",
                "mimeType": "text/plain",
                "filename": "",
                "body": {"size": 13, "data": "SGVsbG8sIHdvcmxkIQ=="}
              },
              {
                "partId": "0.1",
                "mimeType": "text/html",
                "filename": "",
                "body": {"size": 19, "data": "PGgxPkhlbGxvITwvaDE-"}
              }
            ]
          },
          {
            "partId": "1",
            "mimeType": "application/pdf",
            "filename": "receipt.pdf",
            "body": {"attachmentId": "ATT_1", "size": 1024}
          }
        ]
      }
    }
    """#

    static let attachmentJSON = #"""
    {
      "attachmentId": "ATT_1",
      "size": 13,
      "data": "SGVsbG8sIHdvcmxkIQ"
    }
    """#

    static let historyJSON = #"""
    {
      "history": [
        {
          "id": "100",
          "messages": [{"id": "mx", "threadId": "tx"}],
          "messagesAdded": [
            {"message": {"id": "mx", "threadId": "tx", "labelIds": ["INBOX"]}}
          ]
        }
      ],
      "historyId": "101"
    }
    """#
}
