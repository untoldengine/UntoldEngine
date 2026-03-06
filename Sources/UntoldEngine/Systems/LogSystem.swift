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

public final class LogStore: ObservableObject, LoggerSink {
    public static let shared = LogStore()
    @Published public private(set) var entries: [LogEvent] = []

    private let queue = DispatchQueue(label: "engine.log.store", qos: .utility)
    private let maxEntries = 5000

    private init() {}

    public func didLog(_ event: LogEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            entries.append(event)
            if entries.count > maxEntries {
                entries.removeFirst(entries.count - maxEntries)
            }
        }
    }

    public func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.entries.removeAll()
        }
    }
}
