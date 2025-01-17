//
//  Logger.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 5/28/23.
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

public enum Logger {
    // Define a log level
    public static var logLevel: LogLevel = .debug

    public static func log(message: String) {
        // custom implementation for logging
        guard logLevel.rawValue >= LogLevel.info.rawValue else { return }
        print("Log: \(message)")
    }

    public static func logError(message: String) {
        guard logLevel.rawValue >= LogLevel.error.rawValue else { return }
        print("Error: \(message)")
    }

    public static func logWarning(message: String) {
        guard logLevel.rawValue >= LogLevel.warning.rawValue else { return }
        print("Warning: \(message)")
    }

    public static func log(vector: simd_float3) {
        guard logLevel.rawValue >= LogLevel.debug.rawValue else { return }
        let string = String(format: "simd_float3(%f, %f, %f)", vector.x, vector.y, vector.z)
        print(string)
    }

    public static func log(message: String, vector: simd_float3) {
        guard logLevel.rawValue >= LogLevel.debug.rawValue else { return }
        let string = String(format: "simd_float3(%f, %f, %f)", vector.x, vector.y, vector.z)
        print(message)
        print(string)
    }

    public static func log(vector: simd_uint3) {
        guard logLevel.rawValue >= LogLevel.debug.rawValue else { return }
        let string = String(format: "simd_uint3(%d, %d, %d)", vector.x, vector.y, vector.z)
        print(string)
    }

    public static func log(vector: simd_float4) {
        guard logLevel.rawValue >= LogLevel.debug.rawValue else { return }
        let string = String(
            format: "simd_float4(%f, %f, %f, %f)", vector.x, vector.y, vector.z, vector.w
        )
        print(string)
    }

    public static func log(matrix: simd_float3x3) {
        guard logLevel.rawValue >= LogLevel.debug.rawValue else { return }
        print("simd_float3x3:")
        for row in 0 ..< 3 {
            let string = String(
                format: "%f, %f, %f", matrix.columns.0[row], matrix.columns.1[row], matrix.columns.2[row]
            )
            print(string)
        }
    }

    public static func log(matrix: simd_float4x4) {
        guard logLevel.rawValue >= LogLevel.debug.rawValue else { return }
        print("simd_float4x4:")
        for row in 0 ..< 4 {
            let string = String(
                format: "%f, %f, %f, %f", matrix.columns.0[row], matrix.columns.1[row],
                matrix.columns.2[row], matrix.columns.3[row]
            )
            print(string)
        }
    }
}
