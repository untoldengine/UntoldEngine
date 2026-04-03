//
//  UntoldChunkTypes.swift
//  UntoldEngine
//
//  Chunk-oriented helpers and shared constants for the cooked `.untold`
//  runtime asset container.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

public enum UntoldChunkPayloadRules {
    public static let stringTableUsesNullTerminatedUTF8 = true
    public static let chunkPayloadAlignment: UInt64 = UntoldFormat.fileAlignment
}

public enum UntoldVertexPacking {
    private static let tenBitMask: UInt32 = 0x3FF
    private static let twoBitMask: UInt32 = 0x3

    /// Pack a normalized vector into signed-normalized 10:10:10:2.
    /// The top 2 bits are set to zero.
    public static func packNormal(_ normal: SIMD3<Float>) -> UInt32 {
        let x = packSnorm10(normal.x)
        let y = packSnorm10(normal.y)
        let z = packSnorm10(normal.z)
        return x | (y << 10) | (z << 20)
    }

    /// Pack a normalized tangent into signed-normalized 10:10:10:2.
    /// `handedness` is encoded in the top 2 bits as {-1, +1}.
    public static func packTangent(_ tangent: SIMD3<Float>, handedness: Float) -> UInt32 {
        let x = packSnorm10(tangent.x)
        let y = packSnorm10(tangent.y)
        let z = packSnorm10(tangent.z)
        let w = packSnorm2(handedness)
        return x | (y << 10) | (z << 20) | (w << 30)
    }

    public static func unpackNormal(_ packed: UInt32) -> SIMD3<Float> {
        SIMD3<Float>(
            unpackSnorm10(packed & tenBitMask),
            unpackSnorm10((packed >> 10) & tenBitMask),
            unpackSnorm10((packed >> 20) & tenBitMask)
        )
    }

    public static func unpackTangent(_ packed: UInt32) -> (vector: SIMD3<Float>, handedness: Float) {
        let tangent = SIMD3<Float>(
            unpackSnorm10(packed & tenBitMask),
            unpackSnorm10((packed >> 10) & tenBitMask),
            unpackSnorm10((packed >> 20) & tenBitMask)
        )
        let handedness = unpackSnorm2((packed >> 30) & twoBitMask)
        return (tangent, handedness >= 0 ? 1.0 : -1.0)
    }

    private static func packSnorm10(_ value: Float) -> UInt32 {
        let clamped = max(-1.0, min(1.0, value))
        let scaled = Int32((clamped * 511.0).rounded())
        return UInt32(bitPattern: scaled) & tenBitMask
    }

    private static func packSnorm2(_ value: Float) -> UInt32 {
        let sign: Int32 = value < 0 ? -1 : 1
        return UInt32(bitPattern: sign) & twoBitMask
    }

    private static func unpackSnorm10(_ bits: UInt32) -> Float {
        let signed = signExtend(bits, bitWidth: 10)
        return max(-1.0, Float(signed) / 511.0)
    }

    private static func unpackSnorm2(_ bits: UInt32) -> Float {
        let signed = signExtend(bits, bitWidth: 2)
        return signed < 0 ? -1.0 : 1.0
    }

    private static func signExtend(_ value: UInt32, bitWidth: UInt32) -> Int32 {
        let shift = 32 - bitWidth
        return Int32(bitPattern: value << shift) >> shift
    }
}
