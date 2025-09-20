//
//  LogConsoleView.swift
//
//
//  Created by Harold Serrano on 8/10/25.
//
#if canImport(AppKit)
import Combine
import Foundation
import SwiftUI

public final class LogStore: ObservableObject, LoggerSink {
    public static let shared = LogStore()
    @Published public private(set) var entries: [LogEvent] = []

    private let queue = DispatchQueue(label: "engine.log.store", qos: .utility)
    private let maxEntries = 5000

    private init() {}

    public func didLog(_ event: LogEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.entries.append(event)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
        }
    }
}

struct LogConsoleView: View {
    @StateObject private var store = LogStore.shared
    @State private var selectedLevel: LogLevel? = nil
    @State private var search = ""
    @State private var autoScroll = true

    private func passes(_ e: LogEvent) -> Bool {
        (selectedLevel == nil || e.level == selectedLevel!) &&
            (search.isEmpty ||
                e.message.localizedCaseInsensitiveContains(search) ||
                e.category.localizedCaseInsensitiveContains(search))
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("Level", selection: $selectedLevel) {
                    Text("All").tag(LogLevel?.none)
                    Text("Error").tag(LogLevel?.some(.error))
                    Text("Warning").tag(LogLevel?.some(.warning))
                    Text("Info").tag(LogLevel?.some(.info))
                    Text("Debug").tag(LogLevel?.some(.debug))
                    Text("Test").tag(LogLevel?.some(.test))
                }
                .pickerStyle(.segmented)

                TextField("Search…", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)

                Toggle("Auto‑scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)
                /* //Disabling Buttons for now
                                Spacer()

                                Button("Copy") {
                                    let text = store.entries.filter(passes).map {
                                        "[\($0.level)] \($0.message)"
                                    }.joined(separator: "\n")
                                    #if os(macOS)
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(text, forType: .string)
                                    #endif
                                }

                                Button("Export") {
                                    //exportLog(store.entries.filter(passes))
                                }

                                Button("Clear") {
                                    // optional: expose a clear API on Logger/LogStore if you want
                                }
                 */
            }
            .padding(.horizontal, 8)

            ScrollViewReader { proxy in
                List(store.entries.filter(passes)) { e in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(shortTime(e.timestamp))
                            .font(.caption).foregroundColor(.secondary)
                            .frame(width: 84, alignment: .leading)

                        Text("[\(e.category)]")
                            .font(.caption).foregroundColor(.secondary)
                            .frame(width: 120, alignment: .leading)

                        Text(tag(for: e.level))
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(badgeColor(for: e.level).opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Text(e.message)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(4)
                    }
                    .id(e.id)
                }
                .onChange(of: store.entries.last?.id) { _, last in
                    if autoScroll, let last { withAnimation { proxy.scrollTo(last, anchor: .bottom) } }
                }
            }
        }
        .padding(8)
    }

    private func shortTime(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: d)
    }

    private func tag(for level: LogLevel) -> String {
        switch level {
        case .error: return "ERROR"
        case .warning: return "WARN"
        case .info: return "INFO"
        case .debug: return "DEBUG"
        case .test: return "TEST"
        case .none: return ""
        }
    }

    private func badgeColor(for level: LogLevel) -> Color {
        switch level {
        case .error: return .red
        case .warning: return .yellow
        case .info: return .blue
        case .debug: return .gray
        case .test: return .green
        case .none: return .clear
        }
    }
}

private func exportLog(_ entries: [LogEvent]) {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    let text = entries.map { e in
        "[\(f.string(from: e.timestamp))] [\(e.level)] [\(e.category)] \(e.message) (\(e.file):\(e.line))"
    }.joined(separator: "\n")

    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("EngineLog.txt")
    do {
        try text.data(using: .utf8)?.write(to: url)
        #if os(macOS)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        #endif
    } catch {
        Logger.logError(message: "Failed to export log: \(error)", category: "Logger")
    }
}
#endif
