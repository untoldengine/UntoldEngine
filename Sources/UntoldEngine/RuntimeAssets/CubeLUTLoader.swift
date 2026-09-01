//
//  CubeLUTLoader.swift
//  UntoldEngine
//
//  Parses a standard ASCII .cube 3D LUT (the format most color-grading tools
//  export/import) and uploads it directly to a Metal 3D texture. Unlike the
//  scene-wide baked color-management LUT (see UntoldColorManagementRecordV1,
//  loaded through NativeTextureLoader as a proprietary shaper-encoded 2D
//  atlas), a .cube LUT is loaded exactly as authored -- no bake, no custom
//  domain, no native container -- so any LUT from any grading tool works,
//  not just ones produced by this engine's own exporter.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Metal
import simd

/// Parsed contents of a standard ASCII .cube 3D LUT file.
public struct ParsedCubeLUT: Sendable {
    public let size: Int
    public let domainMin: SIMD3<Float>
    public let domainMax: SIMD3<Float>
    /// RGB triplets in the .cube spec's data order: red varies fastest, then
    /// green, then blue -- i.e. index = b*size*size + g*size + r. This is the
    /// same order a Metal 3D texture's slices/rows expect, so no reshuffling
    /// is needed before upload.
    public let data: [SIMD3<Float>]
}

public enum CubeLUTError: Error, CustomStringConvertible {
    case fileNotReadable(String)
    case missingLUT3DSize
    case unsupported1DLUT
    case invalidSize(Int)
    case dataCountMismatch(expected: Int, found: Int)
    case textureCreationFailed

    public var description: String {
        switch self {
        case let .fileNotReadable(path):
            return "Could not read '\(path)' as a .cube LUT"
        case .missingLUT3DSize:
            return "Missing LUT_3D_SIZE header; not a valid 3D .cube LUT"
        case .unsupported1DLUT:
            return "This is a 1D .cube LUT (LUT_1D_SIZE); only 3D LUTs are supported"
        case let .invalidSize(size):
            return "Unsupported LUT_3D_SIZE \(size) (expected \(CubeLUTParser.minSize)-\(CubeLUTParser.maxSize))"
        case let .dataCountMismatch(expected, found):
            return "Expected \(expected) data rows for this LUT_3D_SIZE, found \(found)"
        case .textureCreationFailed:
            return "Failed to create the Metal 3D texture for this LUT"
        }
    }
}

public enum CubeLUTParser {
    public static let minSize = 2
    public static let maxSize = 129

    public static func parse(contentsOf url: URL) throws -> ParsedCubeLUT {
        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw CubeLUTError.fileNotReadable(url.path)
        }
        return try parse(text)
    }

    public static func parse(_ text: String) throws -> ParsedCubeLUT {
        var size: Int?
        var domainMin = SIMD3<Float>(0, 0, 0)
        var domainMax = SIMD3<Float>(1, 1, 1)
        var data: [SIMD3<Float>] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let withoutComment = rawLine.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
            let line = withoutComment.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }

            let parts = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard let keyword = parts.first else { continue }

            switch keyword.uppercased() {
            case "LUT_3D_SIZE":
                guard parts.count >= 2, let n = Int(parts[1]) else { throw CubeLUTError.missingLUT3DSize }
                size = n
            case "LUT_1D_SIZE":
                throw CubeLUTError.unsupported1DLUT
            case "DOMAIN_MIN":
                if parts.count >= 4, let x = Float(parts[1]), let y = Float(parts[2]), let z = Float(parts[3]) {
                    domainMin = SIMD3<Float>(x, y, z)
                }
            case "DOMAIN_MAX":
                if parts.count >= 4, let x = Float(parts[1]), let y = Float(parts[2]), let z = Float(parts[3]) {
                    domainMax = SIMD3<Float>(x, y, z)
                }
            case "TITLE":
                continue
            default:
                // Not a recognized header keyword. If it parses as an "R G B"
                // triplet it's a data row; otherwise it's an unrecognized
                // (forward-compatible) header line and is ignored, per the
                // .cube convention of only requiring LUT_3D_SIZE.
                if parts.count >= 3, let r = Float(parts[0]), let g = Float(parts[1]), let b = Float(parts[2]) {
                    data.append(SIMD3<Float>(r, g, b))
                }
            }
        }

        guard let lutSize = size else { throw CubeLUTError.missingLUT3DSize }
        guard lutSize >= minSize, lutSize <= maxSize else { throw CubeLUTError.invalidSize(lutSize) }

        let expectedCount = lutSize * lutSize * lutSize
        guard data.count == expectedCount else {
            throw CubeLUTError.dataCountMismatch(expected: expectedCount, found: data.count)
        }

        return ParsedCubeLUT(size: lutSize, domainMin: domainMin, domainMax: domainMax, data: data)
    }
}

public enum CubeLUTLoader {
    /// Parse a .cube file and upload it to a Metal 3D texture in one step.
    public static func loadTexture(device: MTLDevice, from url: URL) throws -> (texture: MTLTexture, lut: ParsedCubeLUT) {
        let parsed = try CubeLUTParser.parse(contentsOf: url)
        let texture = try makeTexture(device: device, parsed: parsed)
        return (texture, parsed)
    }

    /// Upload already-parsed LUT data to a Metal 3D texture (RGBA16Float, one mip).
    public static func makeTexture(device: MTLDevice, parsed: ParsedCubeLUT) throws -> MTLTexture {
        let size = parsed.size
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type3D
        descriptor.pixelFormat = .rgba16Float
        descriptor.width = size
        descriptor.height = size
        descriptor.depth = size
        descriptor.mipmapLevelCount = 1
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw CubeLUTError.textureCreationFailed
        }

        var pixels = [Float16](repeating: Float16(1.0), count: size * size * size * 4)
        for (index, rgb) in parsed.data.enumerated() {
            let base = index * 4
            pixels[base] = Float16(rgb.x)
            pixels[base + 1] = Float16(rgb.y)
            pixels[base + 2] = Float16(rgb.z)
            // alpha stays 1.0
        }

        let bytesPerRow = size * 4 * MemoryLayout<Float16>.stride
        let bytesPerImage = bytesPerRow * size
        pixels.withUnsafeBytes { raw in
            texture.replace(
                region: MTLRegionMake3D(0, 0, 0, size, size, size),
                mipmapLevel: 0,
                slice: 0,
                withBytes: raw.baseAddress!,
                bytesPerRow: bytesPerRow,
                bytesPerImage: bytesPerImage
            )
        }

        return texture
    }
}
