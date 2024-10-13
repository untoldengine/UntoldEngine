//
//  Logger.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 5/28/23.
//

import Foundation
import simd

public struct Logger {

  static public func log(message: String) {
    //custom implementation for logging
    print("Log: \(message)")
  }

  static public func logError(message: String) {
    print("Error: \(message)")
  }

  static public func log(vector: simd_float3) {
    let string = String(format: "simd_float3(%f, %f, %f)", vector.x, vector.y, vector.z)
    print(string)
  }

  static public func log(message: String, vector: simd_float3) {
    let string = String(format: "simd_float3(%f, %f, %f)", vector.x, vector.y, vector.z)
    print(message)
    print(string)
  }

  static public func log(vector: simd_uint3) {
    let string = String(format: "simd_uint3(%d, %d, %d)", vector.x, vector.y, vector.z)
    print(string)
  }

  static public func log(vector: simd_float4) {
    let string = String(
      format: "simd_float4(%f, %f, %f, %f)", vector.x, vector.y, vector.z, vector.w)
    print(string)
  }

  static public func log(matrix: simd_float3x3) {
    print("simd_float3x3:")
    for row in 0..<3 {
      let string = String(
        format: "%f, %f, %f", matrix.columns.0[row], matrix.columns.1[row], matrix.columns.2[row])
      print(string)
    }
  }

  static public func log(matrix: simd_float4x4) {
    print("simd_float4x4:")
    for row in 0..<4 {
      let string = String(
        format: "%f, %f, %f, %f", matrix.columns.0[row], matrix.columns.1[row],
        matrix.columns.2[row], matrix.columns.3[row])
      print(string)
    }
  }
}

