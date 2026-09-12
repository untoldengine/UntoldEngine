//
//  UntoldGSPacking.swift
//  UntoldEngine
//
//  Bit-level encoding of the 16-byte `.untoldgs` core record, Morton ordering,
//  the CRC-32 used for per-chunk integrity, and the conversions between the
//  writer's splat representation and the importer's / GPU's structs.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import simd
import zlib

/// One splat as the writer consumes it and the decoder produces it:
/// linear scale, unit quaternion, display-referred colour in 0...1.
public struct UntoldGSSplat: Sendable, Equatable {
    public var position: SIMD3<Float>
    /// Linear per-axis scale (standard deviation), strictly positive.
    public var scale: SIMD3<Float>
    public var rotation: simd_quatf
    /// SH DC colour already mapped to 0...1 (`0.5 + 0.2821 × f_dc`), not linear radiance.
    public var color: SIMD3<Float>
    /// Post-sigmoid opacity in 0...1.
    public var opacity: Float
    /// Higher-order SH coefficients, channel-major, count 0 / 9 / 24 / 45.
    public var sphericalHarmonics: [Float]

    public init(
        position: SIMD3<Float>,
        scale: SIMD3<Float>,
        rotation: simd_quatf,
        color: SIMD3<Float>,
        opacity: Float,
        sphericalHarmonics: [Float] = []
    ) {
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.color = color
        self.opacity = opacity
        self.sphericalHarmonics = sphericalHarmonics
    }

    /// Converts an importer splat. The importer keeps the PLY order `rot_0..rot_3 = (w, x, y, z)`.
    public init(_ splat: GaussianSplat, sphericalHarmonics: [Float] = []) {
        self.init(
            position: SIMD3<Float>(splat.center.x, splat.center.y, splat.center.z),
            scale: SIMD3<Float>(splat.scale.x, splat.scale.y, splat.scale.z),
            rotation: simd_quatf(ix: splat.quat.y, iy: splat.quat.z, iz: splat.quat.w, r: splat.quat.x),
            color: SIMD3<Float>(splat.color.x, splat.color.y, splat.color.z),
            opacity: splat.opacity,
            sphericalHarmonics: sphericalHarmonics
        )
    }

    /// The GPU layout the renderer consumes: covariance from rotation and scale, half precision.
    /// The raw `.ply` load path (`encodeGaussianSplatForTBDR`) converts through this same
    /// initialiser and call, so the rotation-to-covariance math lives here only.
    public func encodedForTBDR() -> EncodedGaussianSplat {
        let covariance = Self.covariance(rotation: rotation, scale: scale)
        return EncodedGaussianSplat(
            position: position,
            covA: simd_half3(Float16(covariance[0, 0]), Float16(covariance[0, 1]), Float16(covariance[0, 2])),
            covB: simd_half3(Float16(covariance[1, 1]), Float16(covariance[1, 2]), Float16(covariance[2, 2])),
            colorAndOpacity: simd_half4(Float16(color.x), Float16(color.y), Float16(color.z), Float16(opacity))
        )
    }

    /// The 3D covariance of a Gaussian with the given unit rotation and per-axis scale:
    /// `(R S)(R S)ᵀ`. A zero-length rotation is treated as the identity.
    public static func covariance(rotation: simd_quatf, scale: SIMD3<Float>) -> simd_float3x3 {
        let unit = simd_length_squared(rotation.vector) > 0 ? simd_normalize(rotation) : simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        let transform = simd_float3x3(unit) * simd_float3x3(diagonal: scale)
        return transform * transform.transpose
    }

    /// Every number the writer packs is finite and the scale is strictly positive (its log is
    /// stored): the packers convert to integers, which traps on NaN, so this is checked before
    /// any of them run.
    public var isFinite: Bool {
        position.x.isFinite && position.y.isFinite && position.z.isFinite
            && scale.x.isFinite && scale.y.isFinite && scale.z.isFinite
            && scale.x > 0 && scale.y > 0 && scale.z > 0
            && rotation.vector.x.isFinite && rotation.vector.y.isFinite
            && rotation.vector.z.isFinite && rotation.vector.w.isFinite
            && color.x.isFinite && color.y.isFinite && color.z.isFinite
            && opacity.isFinite
            && sphericalHarmonics.allSatisfy(\.isFinite)
    }
}

/// The four 32-bit words of one core record.
public struct UntoldGSCoreRecord: Sendable, Equatable {
    /// x: bits 21–31 (11), y: bits 11–20 (10), z: bits 0–10 (11); normalised in the chunk AABB.
    public var position: UInt32
    /// Bits 30–31: index of the largest quaternion component; three 10-bit fields for the rest.
    public var rotation: UInt32
    /// 11/10/11 log-scale normalised in the chunk range.
    public var scale: UInt32
    /// R << 24 | G << 16 | B << 8 | A.
    public var rgba: UInt32

    public init(position: UInt32, rotation: UInt32, scale: UInt32, rgba: UInt32) {
        self.position = position
        self.rotation = rotation
        self.scale = scale
        self.rgba = rgba
    }
}

public enum UntoldGSPacking {
    private static let mask11: UInt32 = 0x7FF
    private static let mask10: UInt32 = 0x3FF
    private static let sqrt2 = Float(2).squareRoot()

    // MARK: 11/10/11 triplets

    /// Packs three normalised components (0...1) as 11, 10 and 11 bits.
    public static func pack11_10_11(_ t: SIMD3<Float>) -> UInt32 {
        let x = UInt32((clamp01(t.x) * 2047).rounded())
        let y = UInt32((clamp01(t.y) * 1023).rounded())
        let z = UInt32((clamp01(t.z) * 2047).rounded())
        return (x << 21) | (y << 11) | z
    }

    public static func unpack11_10_11(_ packed: UInt32) -> SIMD3<Float> {
        SIMD3<Float>(
            Float((packed >> 21) & mask11) / 2047,
            Float((packed >> 11) & mask10) / 1023,
            Float(packed & mask11) / 2047
        )
    }

    /// Normalises `value` into `min...max`; a zero-width range maps to 0.
    public static func normalize(_ value: SIMD3<Float>, min: SIMD3<Float>, max: SIMD3<Float>) -> SIMD3<Float> {
        let extent = max - min
        var t = SIMD3<Float>(repeating: 0)
        for axis in 0 ..< 3 where extent[axis] > 0 {
            t[axis] = (value[axis] - min[axis]) / extent[axis]
        }
        return t
    }

    public static func denormalize(_ t: SIMD3<Float>, min: SIMD3<Float>, max: SIMD3<Float>) -> SIMD3<Float> {
        min + t * (max - min)
    }

    // MARK: Rotation (smallest three)

    /// Encodes a unit quaternion: the largest-magnitude component is dropped and its
    /// index stored in the top two bits; the other three are stored as 10-bit values
    /// in `[-1/√2, 1/√2]`. The quaternion sign is chosen so the dropped component is positive.
    public static func packRotation(_ q: simd_quatf) -> UInt32 {
        var v = q.vector // x, y, z, w
        let lengthSquared = simd_length_squared(v)
        if lengthSquared > 0 {
            v /= lengthSquared.squareRoot()
        } else {
            v = SIMD4<Float>(0, 0, 0, 1)
        }

        var largest = 0
        var largestMagnitude: Float = -1
        for index in 0 ..< 4 {
            let magnitude = abs(v[index])
            if magnitude > largestMagnitude {
                largestMagnitude = magnitude
                largest = index
            }
        }
        if v[largest] < 0 {
            v = -v
        }

        var packed = UInt32(largest) << 30
        var slot: UInt32 = 0
        for index in 0 ..< 4 where index != largest {
            let t = clamp01(v[index] / sqrt2 + 0.5)
            packed |= UInt32((t * 1023).rounded()) << (20 - slot * 10)
            slot += 1
        }
        return packed
    }

    public static func unpackRotation(_ packed: UInt32) -> simd_quatf {
        let largest = Int(packed >> 30)
        var components = SIMD4<Float>(repeating: 0)
        var slot: UInt32 = 0
        var sumSquares: Float = 0
        for index in 0 ..< 4 where index != largest {
            let t = Float((packed >> (20 - slot * 10)) & mask10) / 1023
            let value = (t - 0.5) * sqrt2
            components[index] = value
            sumSquares += value * value
            slot += 1
        }
        components[largest] = max(0, 1 - sumSquares).squareRoot()
        return simd_quatf(vector: components)
    }

    // MARK: Colour

    public static func packRGBA(color: SIMD3<Float>, opacity: Float) -> UInt32 {
        let r = UInt32((clamp01(color.x) * 255).rounded())
        let g = UInt32((clamp01(color.y) * 255).rounded())
        let b = UInt32((clamp01(color.z) * 255).rounded())
        let a = UInt32((clamp01(opacity) * 255).rounded())
        return (r << 24) | (g << 16) | (b << 8) | a
    }

    public static func unpackRGBA(_ packed: UInt32) -> (color: SIMD3<Float>, opacity: Float) {
        let color = SIMD3<Float>(
            Float((packed >> 24) & 0xFF) / 255,
            Float((packed >> 16) & 0xFF) / 255,
            Float((packed >> 8) & 0xFF) / 255
        )
        return (color, Float(packed & 0xFF) / 255)
    }

    // MARK: Whole record

    /// Chunk-level constants a record is encoded against.
    public struct ChunkRanges: Sendable, Equatable {
        public var aabbMin: SIMD3<Float>
        public var aabbMax: SIMD3<Float>
        public var logScaleMin: Float
        public var logScaleMax: Float

        public init(aabbMin: SIMD3<Float>, aabbMax: SIMD3<Float>, logScaleMin: Float, logScaleMax: Float) {
            self.aabbMin = aabbMin
            self.aabbMax = aabbMax
            self.logScaleMin = logScaleMin
            self.logScaleMax = logScaleMax
        }

        public init(entry: UntoldGSChunkEntry) {
            self.init(aabbMin: entry.aabbMin, aabbMax: entry.aabbMax, logScaleMin: entry.logScaleMin, logScaleMax: entry.logScaleMax)
        }

        private var logScaleRange: Float {
            logScaleMax - logScaleMin
        }

        func normalizeLogScale(_ scale: SIMD3<Float>) -> SIMD3<Float> {
            let range = logScaleRange
            guard range > 0 else { return SIMD3<Float>(repeating: 0) }
            let logScale = SIMD3<Float>(log(max(scale.x, Float.leastNormalMagnitude)),
                                        log(max(scale.y, Float.leastNormalMagnitude)),
                                        log(max(scale.z, Float.leastNormalMagnitude)))
            return (logScale - SIMD3<Float>(repeating: logScaleMin)) / range
        }

        func denormalizeLogScale(_ t: SIMD3<Float>) -> SIMD3<Float> {
            let logScale = SIMD3<Float>(repeating: logScaleMin) + t * logScaleRange
            return SIMD3<Float>(exp(logScale.x), exp(logScale.y), exp(logScale.z))
        }
    }

    public static func encode(_ splat: UntoldGSSplat, ranges: ChunkRanges) -> UntoldGSCoreRecord {
        UntoldGSCoreRecord(
            position: pack11_10_11(normalize(splat.position, min: ranges.aabbMin, max: ranges.aabbMax)),
            rotation: packRotation(splat.rotation),
            scale: pack11_10_11(ranges.normalizeLogScale(splat.scale)),
            rgba: packRGBA(color: splat.color, opacity: splat.opacity)
        )
    }

    public static func decode(_ record: UntoldGSCoreRecord, ranges: ChunkRanges) -> UntoldGSSplat {
        let rgba = unpackRGBA(record.rgba)
        return UntoldGSSplat(
            position: denormalize(unpack11_10_11(record.position), min: ranges.aabbMin, max: ranges.aabbMax),
            scale: ranges.denormalizeLogScale(unpack11_10_11(record.scale)),
            rotation: unpackRotation(record.rotation),
            color: rgba.color,
            opacity: rgba.opacity
        )
    }

    // MARK: Spherical harmonics

    /// The SH block uses the renderer's byte contract (`quantizeGaussianSHCoefficient`,
    /// dequantised in `Gaussians.metal` as `(byte - 128) / 128`), so chunk bytes can be
    /// bound to the GPU without conversion.
    public static func packSHCoefficient(_ value: Float) -> UInt8 {
        quantizeGaussianSHCoefficient(value)
    }

    public static func unpackSHCoefficient(_ byte: UInt8) -> Float {
        (Float(byte) - 128) / 128
    }

    // MARK: Morton order

    /// 63-bit Morton key: 21 bits per axis, position normalised over `bounds`.
    public static func mortonKey(_ position: SIMD3<Float>, boundsMin: SIMD3<Float>, boundsMax: SIMD3<Float>) -> UInt64 {
        let t = normalize(position, min: boundsMin, max: boundsMax)
        let maxCoordinate: Float = 2_097_151 // 2^21 - 1
        let x = UInt64((clamp01(t.x) * maxCoordinate).rounded())
        let y = UInt64((clamp01(t.y) * maxCoordinate).rounded())
        let z = UInt64((clamp01(t.z) * maxCoordinate).rounded())
        return spread21(x) | (spread21(y) << 1) | (spread21(z) << 2)
    }

    /// Spreads the low 21 bits of `value` so there are two zero bits between each.
    static func spread21(_ value: UInt64) -> UInt64 {
        var v = value & 0x1FFFFF
        v = (v | (v << 32)) & 0x1F_0000_0000_FFFF
        v = (v | (v << 16)) & 0x1F_0000_FF00_00FF
        v = (v | (v << 8)) & 0x100F_00F0_0F00_F00F
        v = (v | (v << 4)) & 0x10C3_0C30_C30C_30C3
        v = (v | (v << 2)) & 0x1249_2492_4924_9249
        return v
    }

    // MARK: Helpers

    /// Clamps to 0...1; NaN clamps to 0 (Swift's `min`/`max` would propagate it into the
    /// integer conversions of the packers, which trap on NaN).
    static func clamp01(_ value: Float) -> Float {
        guard !value.isNaN else { return 0 }
        return min(max(value, 0), 1)
    }
}

/// The sRGB transfer curve the shaders apply to the stored display-referred colour
/// (`gaussianSRGBToLinear` in `Gaussians.metal`), mirrored so the coarsener averages colours in
/// linear space and maps the mean back once.
public enum UntoldGSColor {
    /// Display-referred (sRGB-encoded) → linear, per channel; negative input clamps to 0.
    public static func linear(fromDisplay color: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(linear(fromDisplay: color.x), linear(fromDisplay: color.y), linear(fromDisplay: color.z))
    }

    public static func linear(fromDisplay value: Float) -> Float {
        let c = max(value, 0)
        return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    /// Linear → display-referred (sRGB-encoded), per channel; the inverse of `linear(fromDisplay:)`.
    public static func display(fromLinear color: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(display(fromLinear: color.x), display(fromLinear: color.y), display(fromLinear: color.z))
    }

    public static func display(fromLinear value: Float) -> Float {
        let l = max(value, 0)
        return l <= 0.003_130_8 ? l * 12.92 : 1.055 * pow(l, 1 / 2.4) - 0.055
    }
}

/// CRC-32 (IEEE 802.3, reflected, polynomial 0xEDB88320) for per-chunk integrity, through the
/// system zlib; `update` streams the checksum over a payload that arrives in pieces (a chunk
/// paged in tier by tier).
public enum UntoldGSCRC32 {
    /// The checksum of `data`, whole.
    public static func checksum(_ data: Data) -> UInt32 {
        var crc = initialValue
        data.withUnsafeBytes { buffer in
            update(&crc, buffer)
        }
        return finalize(crc)
    }

    /// The initial running value of a streamed checksum; feed `update` the payload in any
    /// pieces, in order, then finish with `finalize`.
    public static let initialValue: UInt32 = 0xFFFF_FFFF

    /// Folds `bytes` into the running checksum `crc` (started at `initialValue`): the system
    /// zlib's `crc32` — the same reflected polynomial 0xEDB88320, bit for bit, at the speed of
    /// the platform's implementation whatever this module is compiled with. zlib keeps the
    /// running value in its finalised form, so it is complemented on the way in and out.
    public static func update(_ crc: inout UInt32, _ bytes: UnsafeRawBufferPointer) {
        guard let base = bytes.baseAddress, bytes.count > 0 else { return }
        var value = uLong(crc ^ 0xFFFF_FFFF)
        var offset = 0
        let count = bytes.count
        // zlib takes the length as a 32-bit count: the rare larger payload goes in pieces.
        let piece = 1 << 30
        while offset < count {
            let length = min(piece, count - offset)
            value = crc32(value, base.advanced(by: offset).assumingMemoryBound(to: Bytef.self), uInt(length))
            offset += length
        }
        crc = UInt32(truncatingIfNeeded: value) ^ 0xFFFF_FFFF
    }

    /// The checksum a streamed `update` sequence stands for.
    public static func finalize(_ crc: UInt32) -> UInt32 {
        crc ^ 0xFFFF_FFFF
    }
}
