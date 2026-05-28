//
//  Logger.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

public enum LogLevel: Int, Sendable {
    case none = 0
    case error
    case warning
    case info
    case debug
    case test
}

public enum LogCategory: String, CaseIterable, Sendable {
    case general = "General"
    case ecs = "ECS"
    case oocTiming = "OOCTiming"
    case oocStatus = "OOCStatus"
    case assetLoader = "AssetLoader"
    case tileStreaming = "TileStreaming"
    case streamingHeartbeat = "StreamingHeartbeat"
    case textureStreaming = "TextureStreaming"
    case textureLoading = "TextureLoading"
    case engineStats = "EngineStats"
    case integration = "Integration"
    case xrCamera = "XRCamera"
    case batching = "Batching"
}

public struct LogEvent: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp = Date()
    public let level: LogLevel
    public let message: String
    public let file: String
    public let function: String
    public let line: Int
    public let category: String
}

public protocol LoggerSink: AnyObject {
    func didLog(_ event: LogEvent)
}

public enum Logger {
    private static let state = LoggerState()
    public static var logLevel: LogLevel {
        get { state.logLevel }
        set { state.logLevel = newValue }
    }

    public static func enable(category: LogCategory) {
        state.setCategoryEnabled(category.rawValue, enabled: true)
    }

    public static func disable(category: LogCategory) {
        state.setCategoryEnabled(category.rawValue, enabled: false)
    }

    public static func set(category: LogCategory, enabled: Bool) {
        state.setCategoryEnabled(category.rawValue, enabled: enabled)
    }

    public static func isEnabled(category: LogCategory) -> Bool {
        state.isCategoryEnabled(category.rawValue)
    }

    public static func resetCategoryToggles() {
        state.resetCategoryToggles()
    }

    #if canImport(AppKit)
        private static let sinkQueue = DispatchQueue(label: "engine.logger.sinks", qos: .utility)
        private static let backlogLimit = 2000
    #endif

    public static func addSink(_ sink: LoggerSink) {
        #if canImport(AppKit)
            let sinkBox = WeakBox(value: sink)
            sinkQueue.async {
                // Replay backlog to the new sink (in order).
                let snapshot = state.addSinkAndSnapshotBacklog(sinkBox)
                guard let sink = sinkBox.value else { return }
                for event in snapshot {
                    sink.didLog(event)
                }
            }
        #endif
    }

    private static func emit(level: LogLevel,
                             message: String,
                             category: String = LogCategory.general.rawValue,
                             file: String = #fileID,
                             function: String = #function,
                             line: Int = #line)
    {
        #if canImport(AppKit)
            let event = LogEvent(level: level, message: message, file: file,
                                 function: function, line: line, category: category)

            sinkQueue.async {
                let sinks = state.appendEventAndSnapshotSinks(event, backlogLimit: backlogLimit)
                sinks.forEach { $0.didLog(event) }
            }
        #endif
    }

    public static func log(message: @autoclosure () -> String,
                           category: String = LogCategory.general.rawValue,
                           file: String = #fileID,
                           function: String = #function,
                           line: Int = #line)
    {
        guard logLevel.rawValue >= LogLevel.info.rawValue else { return }
        guard state.isCategoryEnabled(category) else { return }
        let renderedMessage = message()
        print("Log: \(renderedMessage)")
        emit(level: .info, message: renderedMessage, category: category, file: file, function: function, line: line)
    }

    public static func logError(message: @autoclosure () -> String,
                                category: String = LogCategory.general.rawValue,
                                file: String = #fileID,
                                function: String = #function,
                                line: Int = #line)
    {
        guard logLevel.rawValue >= LogLevel.error.rawValue else { return }
        let renderedMessage = message()
        print("Error: \(renderedMessage)")
        emit(level: .error, message: renderedMessage, category: category, file: file, function: function, line: line)
    }

    public static func logWarning(message: @autoclosure () -> String,
                                  category: String = LogCategory.general.rawValue,
                                  file: String = #fileID,
                                  function: String = #function,
                                  line: Int = #line)
    {
        guard logLevel.rawValue >= LogLevel.warning.rawValue else { return }
        let renderedMessage = message()
        print("Warning: \(renderedMessage)")
        emit(level: .warning, message: renderedMessage, category: category, file: file, function: function, line: line)
    }

    public static func log(vector: simd_float3,
                           category: String = LogCategory.general.rawValue,
                           file: String = #fileID,
                           function: String = #function,
                           line: Int = #line)
    {
        guard logLevel.rawValue >= LogLevel.debug.rawValue else { return }
        guard state.isCategoryEnabled(category) else { return }
        let s = String(format: "simd_float3(%f, %f, %f)", vector.x, vector.y, vector.z)
        print(s)
        emit(level: .debug, message: s, category: category, file: file, function: function, line: line)
    }

    public static func log(message: @autoclosure () -> String, vector: simd_float3,
                           category: String = LogCategory.general.rawValue,
                           file: String = #fileID,
                           function: String = #function,
                           line: Int = #line)
    {
        guard logLevel.rawValue >= LogLevel.debug.rawValue else { return }
        guard state.isCategoryEnabled(category) else { return }
        let renderedMessage = message()
        let s = String(format: "simd_float3(%f, %f, %f)", vector.x, vector.y, vector.z)
        print(renderedMessage); print(s)
        emit(level: .debug, message: "\(renderedMessage)  \(s)", category: category, file: file, function: function, line: line)
    }

    // …repeat same idea for simd_uint3, float4, 3x3, 4x4 (compose a string, print, emit)

    #if canImport(AppKit)
        private struct WeakBox: @unchecked Sendable { weak var value: LoggerSink? }
    #endif

    private final class LoggerState: @unchecked Sendable {
        private let lock = NSLock()
        private var _logLevel: LogLevel = .debug
        private let defaultDisabledCategories: Set<String> = [
            LogCategory.oocTiming.rawValue,
            LogCategory.oocStatus.rawValue,
            LogCategory.assetLoader.rawValue,
            LogCategory.tileStreaming.rawValue,
            LogCategory.streamingHeartbeat.rawValue,
            LogCategory.textureStreaming.rawValue,
            LogCategory.textureLoading.rawValue,
            LogCategory.xrCamera.rawValue,
            LogCategory.batching.rawValue,
        ]
        private var categoryOverrides: [String: Bool] = [:]

        var logLevel: LogLevel {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _logLevel
            }
            set {
                lock.lock()
                _logLevel = newValue
                lock.unlock()
            }
        }

        func setCategoryEnabled(_ category: String, enabled: Bool) {
            lock.lock()
            categoryOverrides[category] = enabled
            lock.unlock()
        }

        func isCategoryEnabled(_ category: String) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            if let override = categoryOverrides[category] {
                return override
            }
            return !defaultDisabledCategories.contains(category)
        }

        func resetCategoryToggles() {
            lock.lock()
            categoryOverrides.removeAll(keepingCapacity: true)
            lock.unlock()
        }

        #if canImport(AppKit)
            private var sinks: [WeakBox] = []
            private var backlog: [LogEvent] = []

            func addSinkAndSnapshotBacklog(_ sinkBox: WeakBox) -> [LogEvent] {
                lock.lock()
                sinks.append(sinkBox)
                let snapshot = backlog
                lock.unlock()
                return snapshot
            }

            func appendEventAndSnapshotSinks(_ event: LogEvent, backlogLimit: Int) -> [LoggerSink] {
                lock.lock()
                backlog.append(event)
                if backlog.count > backlogLimit {
                    backlog.removeFirst(backlog.count - backlogLimit)
                }
                sinks = sinks.filter { $0.value != nil }
                let liveSinks = sinks.compactMap(\.value)
                lock.unlock()
                return liveSinks
            }
        #endif
    }
}
