//
//  LogSystem.swift
//  UntoldEngine
//
//  Created by Javier Segura Perez on 14/9/25.
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
