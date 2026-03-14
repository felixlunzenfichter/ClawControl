import XCTest
@testable import ClawControl

@MainActor
final class ConversationStoreTests: XCTestCase {
    func testOnAppStartSendsPingHelloOnlyOnce() async {
        let service = SpyConversationService()
        let store = ConversationStore(service: service, currentThreadId: "thread-1")

        await store.onAppStart()
        await store.onAppStart()

        XCTAssertEqual(service.sentPayloads.map(\.text), ["ping hello"])
        XCTAssertEqual(service.sentPayloads.map(\.threadId), ["thread-1"])
    }

    func testOnAppStartRefreshesMessagesAndObservesPongInSameThread() async {
        let expected = ConversationMessage(id: "1", threadId: "thread-1", timestamp: Date(timeIntervalSince1970: 1), sender: "assistant", text: "pong from bot")
        let service = SpyConversationService(fetchResult: [expected])
        let store = ConversationStore(service: service, currentThreadId: "thread-1")

        await store.onAppStart()

        XCTAssertEqual(store.messages, [expected])
        XCTAssertTrue(store.observedPongInCurrentThread)
    }
}

private final class SpyConversationService: ConversationService {
    typealias SentPayload = (text: String, threadId: String)
    var sentPayloads: [SentPayload] = []
    private let fetchResult: [ConversationMessage]

    init(fetchResult: [ConversationMessage] = []) {
        self.fetchResult = fetchResult
    }

    func fetchMessages(threadId: String) async throws -> [ConversationMessage] {
        fetchResult.filter { $0.threadId == threadId }
    }

    func send(text: String, threadId: String) async throws {
        sentPayloads.append((text, threadId))
    }
}
