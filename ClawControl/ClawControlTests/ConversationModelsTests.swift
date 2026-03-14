import XCTest
@testable import ClawControl

final class ConversationModelsTests: XCTestCase {
    func testParseConversationMessageFromDictionary() {
        let message = ConversationMessage.from(dictionary: [
            "id": "m1",
            "thread_id": "thread-1",
            "timestamp": "2026-03-14T13:00:00Z",
            "sender": "assistant",
            "message": "pong"
        ])

        XCTAssertNotNil(message)
        XCTAssertEqual(message?.id, "m1")
        XCTAssertEqual(message?.threadId, "thread-1")
        XCTAssertEqual(message?.sender, "assistant")
        XCTAssertEqual(message?.text, "pong")
    }

    func testMergeUpdatesByIdAndKeepsChronologicalOrder() {
        let t0 = Date(timeIntervalSince1970: 10)
        let t1 = Date(timeIntervalSince1970: 20)

        let existing = [
            ConversationMessage(id: "m1", threadId: "thread-1", timestamp: t1, sender: "me", text: "old")
        ]

        let incoming = [
            ConversationMessage(id: "m0", threadId: "thread-1", timestamp: t0, sender: "assistant", text: "pong"),
            ConversationMessage(id: "m1", threadId: "thread-1", timestamp: t1, sender: "me", text: "updated")
        ]

        let merged = ConversationState.merged(existing: existing, incoming: incoming)
        XCTAssertEqual(merged.map(\.id), ["m0", "m1"])
        XCTAssertEqual(merged.last?.text, "updated")
    }
}
