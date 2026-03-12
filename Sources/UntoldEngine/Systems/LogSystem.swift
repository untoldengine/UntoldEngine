//
//  LogSystem.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public final class LogStore: ObservableObject, LoggerSink, @unchecked Sendable {
    public static let shared = LogStore()
    @Published public private(set) var entries: [LogEvent] = []

    private let maxEntries = 5000

    private init() {}

    public func didLog(_ event: LogEvent) {
        Task { @MainActor in
            LogStore.shared.append(event)
        }
    }

    public func clear() {
        Task { @MainActor in
            LogStore.shared.clearEntries()
        }
    }

    @MainActor
    private func append(_ event: LogEvent) {
        entries.append(event)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    @MainActor
    private func clearEntries() {
        entries.removeAll()
    }
}
