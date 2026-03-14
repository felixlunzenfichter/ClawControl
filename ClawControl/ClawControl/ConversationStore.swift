import Foundation
import Combine
import Network

protocol ConversationService {
    func fetchMessages(threadId: String) async throws -> [ConversationMessage]
    func send(text: String, threadId: String) async throws
}

private enum CanonicalLog {
    private static let evidenceFileName = "v2-handshake-evidence.log"

    static func timestamp(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    static func resetEvidenceLog() {
        guard let url = evidenceFileURL() else { return }
        try? "".write(to: url, atomically: true, encoding: .utf8)
    }

    static func emit(mode: String = "PROD", device: String = "iPad", type: String = "LOG", file: String, function: String, message: String) {
        let line = "\(timestamp()) | \(mode) | \(device) | \(type) | \(file) | \(function) | \(message)"
        print(line)
        appendToEvidenceLog(line)
    }

    private static func evidenceFileURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(evidenceFileName)
    }

    private static func appendToEvidenceLog(_ line: String) {
        guard let url = evidenceFileURL() else { return }
        let payload = Data((line + "\n").utf8)

        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                try? handle.seekToEnd()
                try? handle.write(contentsOf: payload)
            }
            return
        }

        try? payload.write(to: url)
    }
}

struct HandshakeAck: Decodable {
    let type: String
    let sessionId: String
    let ready: Bool
}

struct PongEnvelope: Decodable {
    let type: String
    let sessionId: String
}

actor TCPHandshakeClient {
    private let host: String
    private let port: UInt16

    init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }

    func runHandshake() async throws -> String {
        let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume(returning: ())
                case .failed(let error):
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            connection.start(queue: .global())
        }

        try await sendLine("start", connection: connection)
        let ackLine = try await receiveLine(connection: connection)
        let ack = try JSONDecoder().decode(HandshakeAck.self, from: Data(ackLine.utf8))

        guard ack.type == "handshake_ack", ack.ready else {
            throw NSError(domain: "Handshake", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid handshake ack"])
        }

        try await sendLine("ping hello|\(ack.sessionId)", connection: connection)
        let pongLine = try await receiveLine(connection: connection)
        let pong = try JSONDecoder().decode(PongEnvelope.self, from: Data(pongLine.utf8))

        guard pong.type == "pong" else {
            throw NSError(domain: "Handshake", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid pong"])
        }

        connection.cancel()

        guard pong.sessionId == ack.sessionId else {
            throw NSError(domain: "Handshake", code: 3, userInfo: [NSLocalizedDescriptionKey: "Pong session mismatch"])
        }

        return ack.sessionId
    }

    private func sendLine(_ line: String, connection: NWConnection) async throws {
        let data = Data((line + "\n").utf8)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }

    private func receiveLine(connection: NWConnection) async throws -> String {
        var full = Data()

        while true {
            let chunk = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    if let data {
                        continuation.resume(returning: data)
                        return
                    }

                    if isComplete {
                        continuation.resume(returning: Data())
                    }
                }
            }

            if chunk.isEmpty {
                throw NSError(domain: "Handshake", code: 4, userInfo: [NSLocalizedDescriptionKey: "Connection closed before newline"])
            }

            full.append(chunk)
            if let newlineIndex = full.firstIndex(of: 0x0A) {
                let lineData = full.prefix(upTo: newlineIndex)
                guard let line = String(data: lineData, encoding: .utf8) else {
                    throw NSError(domain: "Handshake", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8"])
                }
                return line.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }
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
        CanonicalLog.resetEvidenceLog()

        CanonicalLog.emit(file: "conversation-store", function: #function, message: "ipad_started")

        let host = ProcessInfo.processInfo.environment["CLAW_MAC_HOST"] ?? "Felixs-MacBook-Pro.local"
        let port = UInt16(ProcessInfo.processInfo.environment["CLAW_MAC_PORT"] ?? "7878") ?? 7878

        do {
            let client = TCPHandshakeClient(host: host, port: port)
            let sessionId = try await client.runHandshake()
            CanonicalLog.emit(file: "conversation-store", function: #function, message: "handshake_confirmed session=\(sessionId)")
            CanonicalLog.emit(file: "conversation-store", function: #function, message: "ping hello")
            observedPongInCurrentThread = true
            CanonicalLog.emit(file: "conversation-store", function: #function, message: "pong_received_same_session")
            print("AUTO_TEST_PASS: ordered V2 handshake chain observed")
        } catch {
            CanonicalLog.emit(type: "ERROR", file: "conversation-store", function: #function, message: "v2_handshake_failed error=\(error.localizedDescription)")
            print("AUTO_TEST_FAIL: ordered V2 handshake chain missing")
        }

        await refresh()
    }

    func refresh() async {
        do {
            let incoming = try await service.fetchMessages(threadId: currentThreadId)
            messages = ConversationState.merged(existing: messages, incoming: incoming)
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
    }
}
