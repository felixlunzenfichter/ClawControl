import Foundation

struct ConversationMessage: Identifiable, Equatable {
    let id: String
    let threadId: String
    let timestamp: Date
    let sender: String
    let text: String

    static func from(dictionary: [String: Any]) -> ConversationMessage? {
        let id = (dictionary["id"] as? String) ?? UUID().uuidString

        let threadId = (dictionary["threadId"] as? String)
            ?? (dictionary["thread_id"] as? String)
            ?? (dictionary["conversationId"] as? String)
            ?? "current"
        let timestamp = Self.parseDate(from: dictionary["timestamp"]) ?? Date()
        let sender = (dictionary["sender"] as? String)
            ?? (dictionary["author"] as? String)
            ?? "unknown"
        let text = (dictionary["text"] as? String)
            ?? (dictionary["message"] as? String)
            ?? (dictionary["content"] as? String)
            ?? ""

        guard !text.isEmpty else { return nil }

        return ConversationMessage(id: id, threadId: threadId, timestamp: timestamp, sender: sender, text: text)
    }

    private static func parseDate(from value: Any?) -> Date? {
        if let date = value as? Date { return date }
        if let raw = value as? String {
            let iso = ISO8601DateFormatter()
            if let parsed = iso.date(from: raw) { return parsed }

            let fallback = DateFormatter()
            fallback.locale = Locale(identifier: "en_US_POSIX")
            fallback.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return fallback.date(from: raw)
        }
        return nil
    }
}

enum ConversationState {
    static func merged(existing: [ConversationMessage], incoming: [ConversationMessage]) -> [ConversationMessage] {
        var byId: [String: ConversationMessage] = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for message in incoming {
            byId[message.id] = message
        }
        return byId.values.sorted { $0.timestamp < $1.timestamp }
    }
}
