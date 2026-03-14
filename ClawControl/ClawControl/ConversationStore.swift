import Foundation
import Combine

protocol ConversationService {
    func fetchMessages(threadId: String) async throws -> [ConversationMessage]
    func send(text: String, threadId: String) async throws
}

@MainActor
final class ConversationStore: ObservableObject {
    @Published private(set) var messages: [ConversationMessage] = []
    @Published private(set) var observedPongInCurrentThread = false

    let currentThreadId: String
    private let service: ConversationService
    private(set) var didSendStartupMessage = false

    init(service: ConversationService, currentThreadId: String = "current") {
        self.service = service
        self.currentThreadId = currentThreadId
    }

    func onAppStart() async {
        guard !didSendStartupMessage else { return }
        didSendStartupMessage = true

        do {
            try await service.send(text: "ping hello", threadId: currentThreadId)
        } catch {
            // keep app resilient; logging screen remains available
        }

        await refresh()
    }

    func refresh() async {
        do {
            let incoming = try await service.fetchMessages(threadId: currentThreadId)
            messages = ConversationState.merged(existing: messages, incoming: incoming)
            observedPongInCurrentThread = messages.contains {
                $0.threadId == currentThreadId && $0.text.localizedCaseInsensitiveContains("pong")
            }
            print(observedPongInCurrentThread ? "AUTO_TEST_PASS: observed pong in same thread" : "AUTO_TEST_FAIL: pong not observed in same thread")
        } catch {
            // keep existing messages on transient failures
        }
    }
}

final class InMemoryConversationService: ConversationService {
    private var storage: [ConversationMessage]

    init(seed: [ConversationMessage] = []) {
        self.storage = seed
    }

    func fetchMessages(threadId: String) async throws -> [ConversationMessage] {
        storage.filter { $0.threadId == threadId }
    }

    func send(text: String, threadId: String) async throws {
        storage.append(
            ConversationMessage(
                id: UUID().uuidString,
                threadId: threadId,
                timestamp: Date(),
                sender: "me",
                text: text
            )
        )

        if text == "ping hello" {
            storage.append(
                ConversationMessage(
                    id: UUID().uuidString,
                    threadId: threadId,
                    timestamp: Date().addingTimeInterval(0.1),
                    sender: "assistant",
                    text: "pong"
                )
            )
        }
    }
}
