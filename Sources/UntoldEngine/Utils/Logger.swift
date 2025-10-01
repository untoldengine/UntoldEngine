//
//  Logger.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation
import simd

public enum LogLevel: Int {
    case none = 0
    case error
    case warning
    case info
    case debug
    case test
}

public struct LogEvent: Identifiable {
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
    public static var logLevel: LogLevel = .debug
#if canImport(AppKit)
    private static var sinks = [WeakBox]()
    private static let sinkQueue = DispatchQueue(label: "engine.logger.sinks", qos: .utility)

    private struct WeakBox { weak var value: LoggerSink? }

    // Backlog for events emitted before any sinks exist
    private static var backlog: [LogEvent] = []
    private static let backlogLimit = 2000
    #endif
    
    public static func addSink(_ sink: LoggerSink) {
#if canImport(AppKit)
        sinkQueue.async {
            sinks.append(WeakBox(value: sink))

            // Replay backlog to the new sink (in order)
            let snapshot = backlog
            snapshot.forEach { sink.didLog($0) }
        }
        #endif
    }

    private static func emit(level: LogLevel,
                             message: String,
                             category: String = "General",
                             file: String = #fileID,
                             function: String = #function,
                             line: Int = #line)
    {
#if canImport(AppKit)
        let event = LogEvent(level: level, message: message, file: file,
                             function: function, line: line, category: category)

        sinkQueue.async {
            // Store in backlog (trim to ring size)
            backlog.append(event)
            if backlog.count > backlogLimit {
                backlog.removeFirst(backlog.count - backlogLimit)
            }

            // Notify sinks
            sinks = sinks.filter { $0.value != nil }
            sinks.forEach { $0.value?.didLog(event) }
        }
        #endif
    }

    public static func log(message: String,
                           category: String = "General",
                           file: String = #fileID,
                           function: String = #function,
                           line: Int = #line)
    {
        guard logLevel.rawValue >= LogLevel.info.rawValue else { return }
        print("Log: \(message)")
        emit(level: .info, message: message, category: category, file: file, function: function, line: line)
    }

    public static func logError(message: String,
                                category: String = "General",
                                file: String = #fileID,
                                function: String = #function,
                                line: Int = #line)
    {
        guard logLevel.rawValue >= LogLevel.error.rawValue else { return }
        print("Error: \(message)")
        emit(level: .error, message: message, category: category, file: file, function: function, line: line)
    }

    public static func logWarning(message: String,
                                  category: String = "General",
                                  file: String = #fileID,
                                  function: String = #function,
                                  line: Int = #line)
    {
        guard logLevel.rawValue >= LogLevel.warning.rawValue else { return }
        print("Warning: \(message)")
        emit(level: .warning, message: message, category: category, file: file, function: function, line: line)
    }

    public static func log(vector: simd_float3,
                           category: String = "General",
                           file: String = #fileID,
                           function: String = #function,
                           line: Int = #line)
    {
        guard logLevel.rawValue >= LogLevel.debug.rawValue else { return }
        let s = String(format: "simd_float3(%f, %f, %f)", vector.x, vector.y, vector.z)
        print(s)
        emit(level: .debug, message: s, category: category, file: file, function: function, line: line)
    }

    public static func log(message: String, vector: simd_float3,
                           category: String = "General",
                           file: String = #fileID,
                           function: String = #function,
                           line: Int = #line)
    {
        guard logLevel.rawValue >= LogLevel.debug.rawValue else { return }
        let s = String(format: "simd_float3(%f, %f, %f)", vector.x, vector.y, vector.z)
        print(message); print(s)
        emit(level: .debug, message: "\(message)  \(s)", category: category, file: file, function: function, line: line)
    }

    // …repeat same idea for simd_uint3, float4, 3x3, 4x4 (compose a string, print, emit)
}
