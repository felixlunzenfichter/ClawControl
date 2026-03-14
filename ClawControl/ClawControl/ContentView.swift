//
//  ContentView.swift
//  ClawControl
//
//  Created by Felix Lunzenfichter on 14.03.2026.
//

import SwiftUI

struct LogRow: Identifiable {
    let id = UUID()
    let timestamp: String
    let mode: String
    let device: String
    let type: String
    let fileName: String
    let functionName: String
    let message: String
}

@MainActor
struct ContentView: View {
    @StateObject private var conversationStore: ConversationStore

    init(conversationStore: ConversationStore? = nil) {
        _conversationStore = StateObject(wrappedValue: conversationStore ?? ConversationStore(service: InMemoryConversationService()))
    }

    var body: some View {
        TabView {
            LogsView()
                .tabItem {
                    Label("Logs", systemImage: "list.bullet.rectangle")
                }

            ConversationView(store: conversationStore)
                .tabItem {
                    Label("Conversation", systemImage: "message")
                }
        }
        .task {
            await conversationStore.onAppStart()
        }
    }
}

private struct LogsView: View {
    private let rows = LogRow.sampleRows

    var body: some View {
        NavigationStack {
            List(rows) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(row.timestamp)
                            .font(.caption.monospaced())
                        Text(row.mode)
                            .font(.caption.weight(.semibold))
                        Text(row.device)
                            .font(.caption)
                        Text(row.type)
                            .font(.caption)
                    }

                    HStack(spacing: 10) {
                        Text(row.fileName)
                            .font(.caption.monospaced())
                        Text(row.functionName)
                            .font(.caption.monospaced())
                    }

                    Text(row.message)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("V1 Logs")
        }
    }
}

private struct ConversationView: View {
    @ObservedObject var store: ConversationStore

    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            List(store.messages) { message in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(formatter.string(from: message.timestamp))
                            .font(.caption.monospaced())
                        Text(message.sender)
                            .font(.caption.weight(.semibold))
                    }
                    Text(message.text)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Conversation")
            .refreshable {
                await store.refresh()
            }
        }
    }
}

private extension LogRow {
    static let sampleRows: [LogRow] = sampleLogLines
        .split(separator: "\n")
        .compactMap { parse(String($0)) }

    static let sampleLogLines = """
13:53:30.021 | PROD | Mac | LOG | mac-server | start | Mac server started
13:53:30.022 | PROD | Mac | LOG | mac-server | handleCommand | Received command: gateway.connect
13:53:30.022 | PROD | Mac | LOG | mac-server | connectGateway | Connecting to OpenClaw Gateway
13:53:30.022 | PROD | Mac | LOG | mac-server | connectGateway | Connected to OpenClaw Gateway
"""

    static func parse(_ line: String) -> LogRow? {
        let parts = line.components(separatedBy: " | ")
        guard parts.count >= 7 else { return nil }

        return LogRow(
            timestamp: parts[0],
            mode: parts[1],
            device: parts[2],
            type: parts[3],
            fileName: parts[4],
            functionName: parts[5],
            message: parts.dropFirst(6).joined(separator: " | ")
        )
    }
}

#Preview {
    ContentView()
}
