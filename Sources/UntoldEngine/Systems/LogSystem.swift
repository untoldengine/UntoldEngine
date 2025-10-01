//
//  LogSystem.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

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
            self.entries.append(event)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
        }
    }
}
