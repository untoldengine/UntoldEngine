//
//  SPZReader.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Compression
import CShaderTypes
import Foundation
import simd

/// Reads Niantic's SPZ Gaussian-splat container (legacy gzip versions 2-3 only) into the same
/// `GaussianSplatAsset` shape `PLYReader` produces, so every downstream consumer (the `.untoldgs`
/// cooker/writer) is format-neutral.
///
/// SPZ version 1 used an unreleased float16 position encoding and is rejected. SPZ version 4
/// (NGSP magic at the start of the raw file, ZSTD-compressed attribute streams) is a different
/// container entirely and is explicitly out of scope — reject it too. Verified against Niantic's
/// reference implementation (`nianticlabs/spz`, `src/cc/load-spz.cc` / `splat-utils.h`), not a
/// secondhand summary of the format.
public class SPZReader {
    // MARK: - Format constants

    /// `NGSP` read as a little-endian `UInt32` — both the legacy gzip payload's embedded header
    /// magic and the raw first 4 bytes of an (unsupported) v4 NGSP file.
    private static let ngspMagic: UInt32 = 0x5053_474E

    private static let minSupportedVersion: UInt32 = 2
    private static let maxSupportedVersion: UInt32 = 3
    /// Versions at or above this store rotations with `packQuaternionSmallestThree` (4 bytes:
    /// 2-bit largest-component index + three signed 9-bit magnitudes). Below it, versions store
    /// `packQuaternionFirstThree` (3 bytes: xyz only, w reconstructed as non-negative).
    private static let smallestThreeQuaternionVersion: UInt32 = 3

    /// SH DC-component scale factor: colors are quantized as `byte = round((dc*colorScale+0.5)*255)`.
    /// Not the same constant as `C0` below — this one only exists to keep the byte quantization
    /// centered, matching Niantic's `colorScale` in `splat-utils.h`.
    private static let colorScale: Float = 0.15
    /// SH0 -> RGB constant: `rgb = 0.5 + C0 * dc`. Same value `PLYReader` uses for `f_dc_*`, since
    /// both formats store the same raw SH DC coefficient underneath their own byte quantization.
    private static let C0: Float = 0.282_094_79

    /// `1/sqrt(2)`, the smallest-three encoding's magnitude scale (each non-largest quaternion
    /// component is at most `1/sqrt(2)` once the largest component is factored out).
    private static let sqrt1_2: Float = 0.707_106_78

    /// RUB (SPZ's coordinate system) -> RDF (this engine's, matching `PLYReader`'s zero-conversion
    /// convention) is a within-family flip: X unchanged, Y and Z negated. Verified against
    /// Niantic's `coordinateConverter(RUB, RDF, ...)`, not assumed from the axis names.
    private static let flipP = SIMD3<Float>(1, -1, -1)
    /// Same flip applied to a quaternion's x, y, z components; w is never flipped.
    private static let flipQ = SIMD3<Float>(1, -1, -1)
    /// Per-rest-coefficient sign flip for RUB->RDF, indices 0...14 (degree 0...3, the engine's SH
    /// cap). Same value applies to a coefficient's R, G and B channel alike. Derived from
    /// Niantic's `coordinateConverter`'s `flipSh` table with x=1,y=-1,z=-1 substituted in — not
    /// hand-derived, since a sign error here corrupts higher SH bands silently (the DC term/base
    /// color would still look right).
    private static let flipSh: [Float] = [-1, -1, 1, -1, 1, 1, -1, 1, -1, 1, -1, -1, 1, -1, 1]

    // MARK: - Public Methods

    /// Reads Gaussian geometry and preserves all spherical-harmonic coefficients, mirroring
    /// `PLYReader.readGaussianAsset(from:)`'s output shape exactly.
    public static func readGaussianAsset(from url: URL) throws -> GaussianSplatAsset {
        let fileData = try Data(contentsOf: url)
        let bytes = [UInt8](fileData)
        guard bytes.count >= 4 else {
            throw SPZError.invalidFormat("File too short to contain an SPZ magic number")
        }
        if readUInt32LE(bytes, at: 0) == ngspMagic {
            throw SPZError.unsupportedVersion(4)
        }
        guard bytes.count >= 2, bytes[0] == 0x1F, bytes[1] == 0x8B else {
            throw SPZError.invalidFormat("Not a gzip-wrapped SPZ file (only legacy versions 2-3 are supported)")
        }
        let decompressed = try gunzip(bytes)
        return try parseLegacyPayload(decompressed)
    }

    // MARK: - Gzip container

    /// Strips the gzip wrapper and inflates the raw DEFLATE body via `Compression`'s
    /// `COMPRESSION_ZLIB` (raw DEFLATE, no zlib header — the same framework already used for LZ4
    /// in `UntoldReader.swift`, so no new dependency). `Compression` has no gzip *container*
    /// decoder, only the underlying algorithms, so the 10+-byte header and 8-byte trailer are
    /// parsed here by hand.
    private static func gunzip(_ bytes: [UInt8]) throws -> [UInt8] {
        guard bytes.count >= 18, bytes[2] == 8 else { // CM must be 8 (deflate); 18 = 10-byte header + 8-byte trailer minimum
            throw SPZError.invalidFormat("Not a valid gzip stream")
        }
        let flags = bytes[3]
        var offset = 10
        if flags & 0x04 != 0 { // FEXTRA
            guard offset + 2 <= bytes.count else {
                throw SPZError.invalidFormat("Truncated gzip FEXTRA field")
            }
            let xlen = Int(bytes[offset]) | (Int(bytes[offset + 1]) << 8)
            offset += 2 + xlen
        }
        if flags & 0x08 != 0 { // FNAME
            offset = try skipNullTerminatedField(bytes, from: offset)
        }
        if flags & 0x10 != 0 { // FCOMMENT
            offset = try skipNullTerminatedField(bytes, from: offset)
        }
        if flags & 0x02 != 0 { // FHCRC
            offset += 2
        }
        guard offset + 8 <= bytes.count else {
            throw SPZError.invalidFormat("Truncated gzip header")
        }

        // The trailer is the LAST 8 bytes of the stream: [CRC32 4B][ISIZE 4B]. ISIZE (the
        // uncompressed size, mod 2^32) is the file's final 4 bytes -- not the first 4 of the
        // trailer, which is CRC32. Getting this backwards reads the wrong output size and either
        // truncates the decode or crashes on the size mismatch below.
        let isizeOffset = bytes.count - 4
        let isize = UInt32(bytes[isizeOffset])
            | (UInt32(bytes[isizeOffset + 1]) << 8)
            | (UInt32(bytes[isizeOffset + 2]) << 16)
            | (UInt32(bytes[isizeOffset + 3]) << 24)
        guard isize > 0 else {
            throw SPZError.invalidFormat("Gzip trailer declares an empty payload")
        }

        let deflateEnd = bytes.count - 8
        guard offset < deflateEnd else {
            throw SPZError.invalidFormat("Gzip stream has no deflate body")
        }
        let deflateBody = Array(bytes[offset ..< deflateEnd])

        var output = [UInt8](repeating: 0, count: Int(isize))
        let written = output.withUnsafeMutableBytes { outBuf -> Int in
            deflateBody.withUnsafeBytes { inBuf -> Int in
                compression_decode_buffer(
                    outBuf.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    Int(isize),
                    inBuf.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    deflateBody.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard written == Int(isize) else {
            throw SPZError.decompressionFailed("expected \(isize) bytes, got \(written)")
        }
        return output
    }

    private static func skipNullTerminatedField(_ bytes: [UInt8], from start: Int) throws -> Int {
        var i = start
        while i < bytes.count, bytes[i] != 0 {
            i += 1
        }
        guard i < bytes.count else {
            throw SPZError.invalidFormat("Unterminated gzip header field")
        }
        return i + 1
    }

    // MARK: - Legacy payload (versions 2-3)

    /// Layout: 16-byte header, then six non-interleaved streams back to back in this exact order
    /// -- positions, alphas, colors, scales, rotations, sh -- matching
    /// `serializePackedGaussians` in the reference implementation. Each stream's length is
    /// derived from the header (`numPoints`, `shDegree`, `version`), not stored, so a truncated
    /// or corrupt file is only caught by the bounds check on each stream read below.
    private static func parseLegacyPayload(_ bytes: [UInt8]) throws -> GaussianSplatAsset {
        guard bytes.count >= 16 else {
            throw SPZError.invalidFormat("Decompressed payload shorter than the 16-byte header")
        }
        guard readUInt32LE(bytes, at: 0) == ngspMagic else {
            throw SPZError.invalidFormat("Missing NGSP magic in decompressed payload")
        }
        let version = readUInt32LE(bytes, at: 4)
        guard version >= minSupportedVersion, version <= maxSupportedVersion else {
            throw SPZError.unsupportedVersion(version)
        }
        let numPointsRaw = readUInt32LE(bytes, at: 8)
        guard numPointsRaw > 0, numPointsRaw <= UInt32(Int32.max) else {
            throw SPZError.invalidData("Invalid point count: \(numPointsRaw)")
        }
        let numPoints = Int(numPointsRaw)
        let shDegree = Int(bytes[12])
        // The engine caps SH at degree 3 everywhere (UntoldGSCookOptions, PLYReader); SPZ itself
        // allows degree 4, which is rejected here rather than silently truncated.
        guard shDegree <= 3 else {
            throw SPZError.unsupportedSHDegree(shDegree)
        }
        let fractionalBits = Int32(bytes[13])
        let flags = bytes[14]
        if flags & 0x02 != 0 { // FlagHasExtensions
            Logger.log(
                message: "[Gaussian][SPZ] File declares extensions; ignoring them (unsupported here) -- point data itself is unaffected",
                category: LogCategory.gaussian.rawValue
            )
        }

        let usesQuaternionSmallestThree = version >= smallestThreeQuaternionVersion
        let shDim = shDimForDegree(shDegree) // rest coefficients per channel: 0, 3, 8, 15 for degree 0...3

        var offset = 16
        func takeStream(_ count: Int, name: String) throws -> [UInt8] {
            guard offset + count <= bytes.count else {
                throw SPZError.invalidData("Truncated \(name) stream")
            }
            defer { offset += count }
            return Array(bytes[offset ..< offset + count])
        }

        let positions = try takeStream(numPoints * 9, name: "positions")
        let alphas = try takeStream(numPoints, name: "alphas")
        let colors = try takeStream(numPoints * 3, name: "colors")
        let scales = try takeStream(numPoints * 3, name: "scales")
        let rotations = try takeStream(numPoints * (usesQuaternionSmallestThree ? 4 : 3), name: "rotations")
        let shBytes = try takeStream(numPoints * shDim * 3, name: "sh")

        let positionScale: Float = 1.0 / Float(1 << fractionalBits)
        var splats: [GaussianSplat] = []
        splats.reserveCapacity(numPoints)
        var shCoefficients: [Float] = []
        let coefficientsPerChannel = shDim + 1
        if shDim > 0 {
            shCoefficients.reserveCapacity(numPoints * coefficientsPerChannel * 3)
        }

        for i in 0 ..< numPoints {
            let position = decodePosition(positions, at: i, scale: positionScale)
            let scale = decodeScale(scales, at: i)
            let quat = decodeRotation(rotations, at: i, usesQuaternionSmallestThree: usesQuaternionSmallestThree)
            let opacity = Float(alphas[i]) / 255.0
            let (dcR, dcG, dcB) = decodeColorDC(colors, at: i)

            splats.append(GaussianSplat(
                center: simd_float4(position.x, position.y, position.z, 1.0),
                scale: simd_float4(scale.x, scale.y, scale.z, 1.0),
                color: simd_float4(dcR * C0 + 0.5, dcG * C0 + 0.5, dcB * C0 + 0.5, opacity),
                quat: quat,
                opacity: opacity
            ))

            // Transpose SPZ's on-disk coefficient-major/channel-minor SH layout (R,G,B triple per
            // coefficient) into the engine's channel-major layout (all of R, then all of G, then
            // all of B) that PLYReader's GaussianSphericalHarmonics.coefficients already uses.
            if shDim > 0 {
                let shBase = i * shDim * 3
                for channel in 0 ..< 3 {
                    let dc = channel == 0 ? dcR : (channel == 1 ? dcG : dcB)
                    shCoefficients.append(dc)
                    for k in 0 ..< shDim {
                        let raw = unquantizeSH(shBytes[shBase + k * 3 + channel])
                        shCoefficients.append(raw * flipSh[k])
                    }
                }
            } else {
                shCoefficients.append(dcR)
                shCoefficients.append(dcG)
                shCoefficients.append(dcB)
            }
        }

        let (filteredSplats, filteredCoefficients) = filterNegligibleOpacityGaussianSplats(
            splats: splats,
            shCoefficients: shCoefficients,
            coefficientsPerSplat: coefficientsPerChannel * 3,
            sourceTag: "SPZ"
        )

        let sphericalHarmonics = GaussianSphericalHarmonics(
            degree: shDegree,
            coefficientsPerChannel: coefficientsPerChannel,
            coefficients: filteredCoefficients
        )
        return GaussianSplatAsset(splats: filteredSplats, sphericalHarmonics: sphericalHarmonics)
    }

    // MARK: - Per-splat decoding

    private static func decodePosition(_ positions: [UInt8], at i: Int, scale: Float) -> SIMD3<Float> {
        let base = i * 9
        var raw = SIMD3<Float>(repeating: 0)
        for axis in 0 ..< 3 {
            let b0 = positions[base + axis * 3 + 0]
            let b1 = positions[base + axis * 3 + 1]
            let b2 = positions[base + axis * 3 + 2]
            var fixed = Int32(b0) | (Int32(b1) << 8) | (Int32(b2) << 16)
            if fixed & 0x0080_0000 != 0 { fixed -= 0x0100_0000 } // sign-extend a 24-bit value
            raw[axis] = Float(fixed) * scale
        }
        return raw * flipP
    }

    private static func decodeScale(_ scales: [UInt8], at i: Int) -> SIMD3<Float> {
        let base = i * 3
        // Log-scale byte, same convention PLYReader's scale_0/1/2 use -- exp() gives the linear
        // scale. No coordinate flip: these are unsigned ellipsoid axis lengths in the splat's own
        // local frame: the quaternion (already flipped) carries all orientation information.
        let logScale = SIMD3<Float>(
            Float(scales[base]), Float(scales[base + 1]), Float(scales[base + 2])
        ) / 16.0 - 10.0
        return SIMD3<Float>(exp(logScale.x), exp(logScale.y), exp(logScale.z))
    }

    /// Returns the engine's `(w, x, y, z)` quaternion convention (see `GaussianSplat.quat` /
    /// `UntoldGSPacking.swift`'s `simd_quatf(ix: .y, iy: .z, iz: .w, r: .x)`), already RUB->RDF
    /// flipped.
    private static func decodeRotation(_ rotations: [UInt8], at i: Int, usesQuaternionSmallestThree: Bool) -> simd_float4 {
        var x: Float
        var y: Float
        var z: Float
        var w: Float
        if usesQuaternionSmallestThree {
            let base = i * 4
            let comp = UInt32(rotations[base])
                | (UInt32(rotations[base + 1]) << 8)
                | (UInt32(rotations[base + 2]) << 16)
                | (UInt32(rotations[base + 3]) << 24)
            let largest = Int(comp >> 30)
            let mask: UInt32 = (1 << 9) - 1
            var components: [Float] = [0, 0, 0, 0]
            var sumSquares: Float = 0
            var remaining = comp
            for idx in stride(from: 3, through: 0, by: -1) where idx != largest {
                let mag = remaining & mask
                let negative = (remaining >> 9) & 1 == 1
                remaining >>= 10
                var value = sqrt1_2 * Float(mag) / Float(mask)
                if negative { value = -value }
                components[idx] = value
                sumSquares += value * value
            }
            components[largest] = sqrt(max(0, 1 - sumSquares))
            x = components[0]; y = components[1]; z = components[2]; w = components[3]
        } else {
            let base = i * 3
            x = Float(rotations[base]) / 127.5 - 1
            y = Float(rotations[base + 1]) / 127.5 - 1
            z = Float(rotations[base + 2]) / 127.5 - 1
            w = sqrt(max(0, 1 - (x * x + y * y + z * z)))
        }
        // RUB -> RDF flip on x, y, z; w is never flipped.
        x *= flipQ.x
        y *= flipQ.y
        z *= flipQ.z
        return simd_float4(w, x, y, z)
    }

    private static func decodeColorDC(_ colors: [UInt8], at i: Int) -> (Float, Float, Float) {
        let base = i * 3
        let dcR = (Float(colors[base]) / 255.0 - 0.5) / colorScale
        let dcG = (Float(colors[base + 1]) / 255.0 - 0.5) / colorScale
        let dcB = (Float(colors[base + 2]) / 255.0 - 0.5) / colorScale
        return (dcR, dcG, dcB)
    }

    private static func unquantizeSH(_ byte: UInt8) -> Float {
        (Float(byte) - 128.0) / 128.0
    }

    private static func shDimForDegree(_ degree: Int) -> Int {
        switch degree {
        case 0: return 0
        case 1: return 3
        case 2: return 8
        case 3: return 15
        default: return 0
        }
    }

    private static func readUInt32LE(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        UInt32(bytes[offset])
            | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16)
            | (UInt32(bytes[offset + 3]) << 24)
    }
}

// MARK: - Errors

public enum SPZError: Error, CustomStringConvertible {
    case invalidFormat(String)
    case unsupportedVersion(UInt32)
    case unsupportedSHDegree(Int)
    case invalidData(String)
    case decompressionFailed(String)

    public var description: String {
        switch self {
        case let .invalidFormat(msg):
            return "Invalid SPZ format: \(msg)"
        case let .unsupportedVersion(version):
            return version == 4
                ? "Unsupported SPZ version: 4 (NGSP/ZSTD container is not yet supported; only legacy gzip versions 2-3 are)"
                : "Unsupported SPZ version: \(version) (only legacy gzip versions 2-3 are supported)"
        case let .unsupportedSHDegree(degree):
            return "Unsupported spherical-harmonic degree: \(degree) (this engine supports 0...3)"
        case let .invalidData(msg):
            return "Invalid data: \(msg)"
        case let .decompressionFailed(msg):
            return "Gzip decompression failed: \(msg)"
        }
    }
}
