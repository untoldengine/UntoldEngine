//
//  PLYReader.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// Note: This PLY Reader was implemented with the use of AI.

import CShaderTypes
import Foundation
import simd

public enum PLYFormat {
    case ascii
    case binaryLittleEndian
    case binaryBigEndian
}

public struct PLYProperty {
    let name: String
    let type: String
    let listCountType: String?
    let listElementType: String?

    var isList: Bool {
        listCountType != nil && listElementType != nil
    }
}

public struct PLYElement {
    let name: String
    let count: Int
    var properties: [PLYProperty]
}

public struct PLYHeader {
    var format: PLYFormat
    var version: String
    var elements: [PLYElement]
    var comments: [String]
}

/// Contiguous spherical-harmonic coefficients for a Gaussian asset.
///
/// Coefficients are stored per splat in channel-major order:
/// `R[0 ... n], G[0 ... n], B[0 ... n]`, where coefficient zero is the DC
/// term and `n + 1 == coefficientsPerChannel`.
public struct GaussianSphericalHarmonics: Sendable {
    public let degree: Int
    public let coefficientsPerChannel: Int
    public let coefficients: [Float]

    public var coefficientsPerSplat: Int {
        coefficientsPerChannel * 3
    }
}

/// CPU import representation for a Gaussian PLY asset.
public struct GaussianSplatAsset {
    public let splats: [GaussianSplat]
    public let sphericalHarmonics: GaussianSphericalHarmonics?
}

public class PLYReader {
    // MARK: - Public Methods

    /// Reads a PLY file and extracts Gaussian splat data
    /// - Parameter url: URL to the PLY file
    /// - Returns: Array of GaussianSplat structs
    /// - Throws: Error if file cannot be read or parsed
    public static func readGaussianSplats(from url: URL) throws -> [GaussianSplat] {
        try readGaussianAsset(from: url).splats
    }

    /// Reads Gaussian geometry and preserves all spherical-harmonic coefficients.
    public static func readGaussianAsset(from url: URL) throws -> GaussianSplatAsset {
        let data = try Data(contentsOf: url)
        let (header, bodyOffset) = try parseHeader(from: data)

        // Find the vertex element (Gaussian splats are typically stored as vertices)
        guard let vertexElement = header.elements.first(where: { $0.name == "vertex" }) else {
            throw PLYError.missingElement("vertex")
        }

        let shSchema = try sphericalHarmonicSchema(for: vertexElement.properties)

        // Parse the body based on format
        let parsed: ([GaussianSplat], [Float])
        switch header.format {
        case .ascii:
            parsed = try parseASCIIGaussians(data: data, bodyOffset: bodyOffset, element: vertexElement, shSchema: shSchema)
        case .binaryLittleEndian:
            parsed = try parseBinaryGaussians(data: data, bodyOffset: bodyOffset, element: vertexElement, bigEndian: false, shSchema: shSchema)
        case .binaryBigEndian:
            parsed = try parseBinaryGaussians(data: data, bodyOffset: bodyOffset, element: vertexElement, bigEndian: true, shSchema: shSchema)
        }

        if let shSchema,
           parsed.1.count != vertexElement.count * shSchema.coefficientsPerSplat
        {
            throw PLYError.invalidData("Spherical-harmonic coefficient data is incomplete")
        }

        let (filteredSplats, filteredCoefficients) = filterNegligibleOpacitySplats(
            splats: parsed.0,
            shCoefficients: parsed.1,
            coefficientsPerSplat: shSchema?.coefficientsPerSplat ?? 0
        )

        let sphericalHarmonics = shSchema.map {
            GaussianSphericalHarmonics(
                degree: $0.degree,
                coefficientsPerChannel: $0.coefficientsPerChannel,
                coefficients: filteredCoefficients
            )
        }
        return GaussianSplatAsset(splats: filteredSplats, sphericalHarmonics: sphericalHarmonics)
    }

    // A splat's peak alpha (at its own center, where the Gaussian falloff is 1) equals its
    // opacity — see fragmentGaussianTBDRShader's `alpha = opacity * exp(power)`, power <= 0.
    // The shader itself discards any fragment below this same threshold, so a splat whose
    // opacity never reaches it can never contribute a visible pixel anywhere in its extent.
    // Dropping it here removes it from vertex shading, rasterization, and per-fragment ALU
    // entirely instead of paying that cost every frame only to discard the result — this is
    // a lossless cull (identical rendered image), not a quality/perf tradeoff.
    private static let minRetainedOpacity: Float = 1.0 / 255.0

    private static func filterNegligibleOpacitySplats(
        splats: [GaussianSplat],
        shCoefficients: [Float],
        coefficientsPerSplat: Int
    ) -> ([GaussianSplat], [Float]) {
        guard splats.contains(where: { $0.opacity < minRetainedOpacity }) else {
            return (splats, shCoefficients)
        }

        var keptSplats: [GaussianSplat] = []
        keptSplats.reserveCapacity(splats.count)
        var keptCoefficients: [Float] = []
        if coefficientsPerSplat > 0 {
            keptCoefficients.reserveCapacity(shCoefficients.count)
        }

        for (index, splat) in splats.enumerated() {
            guard splat.opacity >= minRetainedOpacity else { continue }
            keptSplats.append(splat)
            if coefficientsPerSplat > 0 {
                let start = index * coefficientsPerSplat
                keptCoefficients.append(contentsOf: shCoefficients[start ..< start + coefficientsPerSplat])
            }
        }

        Logger.log(
            message: String(
                format: "[Gaussian][PLY] Culled %d/%d splats below visibility threshold (opacity < %.4f)",
                splats.count - keptSplats.count, splats.count, minRetainedOpacity
            ),
            category: LogCategory.gaussian.rawValue
        )

        return (keptSplats, keptCoefficients)
    }

    // MARK: - Header Parsing

    private static func parseHeader(from data: Data) throws -> (PLYHeader, Int) {
        var header = PLYHeader(format: .ascii, version: "1.0", elements: [], comments: [])

        // Read header line by line until we find binary data
        var bodyOffset = 0
        var currentElement: PLYElement?
        var headerLines: [String] = []

        // Read the header byte by byte, line by line
        var lineStart = 0
        for i in 0 ..< min(data.count, 100_000) {
            if data[i] == 0x0A { // newline
                let lineData = data.subdata(in: lineStart ..< i)
                guard let line = String(data: lineData, encoding: .utf8) else {
                    throw PLYError.invalidFormat("Cannot decode header as UTF-8")
                }
                headerLines.append(line)

                if line.trimmingCharacters(in: .whitespaces) == "end_header" {
                    bodyOffset = i + 1 // +1 to skip the newline after end_header
                    break
                }

                lineStart = i + 1
            }
        }

        // First line must be "ply"
        guard headerLines.first?.trimmingCharacters(in: .whitespaces) == "ply" else {
            throw PLYError.invalidFormat("File does not start with 'ply'")
        }

        // Parse header lines
        for line in headerLines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine.isEmpty || trimmedLine.hasPrefix("comment") {
                if trimmedLine.hasPrefix("comment") {
                    header.comments.append(String(trimmedLine.dropFirst(7).trimmingCharacters(in: .whitespaces)))
                }
                continue
            }

            let parts = trimmedLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard let keyword = parts.first else { continue }

            switch keyword {
            case "ply":
                continue

            case "format":
                guard parts.count >= 3 else { throw PLYError.invalidFormat("Invalid format line") }
                header.version = parts[2]
                switch parts[1] {
                case "ascii":
                    header.format = .ascii
                case "binary_little_endian":
                    header.format = .binaryLittleEndian
                case "binary_big_endian":
                    header.format = .binaryBigEndian
                default:
                    throw PLYError.unsupportedFormat(parts[1])
                }

            case "element":
                // Save previous element if exists
                if let element = currentElement {
                    header.elements.append(element)
                }
                guard parts.count >= 3, let count = Int(parts[2]) else {
                    throw PLYError.invalidFormat("Invalid element line")
                }
                currentElement = PLYElement(name: parts[1], count: count, properties: [])

            case "property":
                guard var element = currentElement else {
                    throw PLYError.invalidFormat("Property without element")
                }

                if parts[1] == "list" {
                    // List property: property list <count_type> <element_type> <name>
                    guard parts.count >= 5 else {
                        throw PLYError.invalidFormat("Invalid list property")
                    }
                    let property = PLYProperty(
                        name: parts[4],
                        type: "list",
                        listCountType: parts[2],
                        listElementType: parts[3]
                    )
                    element.properties.append(property)
                } else {
                    // Simple property: property <type> <name>
                    guard parts.count >= 3 else {
                        throw PLYError.invalidFormat("Invalid property")
                    }
                    let property = PLYProperty(
                        name: parts[2],
                        type: parts[1],
                        listCountType: nil,
                        listElementType: nil
                    )
                    element.properties.append(property)
                }
                currentElement = element

            case "end_header":
                // Save last element
                if let element = currentElement {
                    header.elements.append(element)
                }
                return (header, bodyOffset)

            default:
                // Unknown keyword, skip
                break
            }
        }

        throw PLYError.invalidFormat("Missing end_header")
    }

    // MARK: - ASCII Parsing

    private static func parseASCIIGaussians(
        data: Data,
        bodyOffset: Int,
        element: PLYElement,
        shSchema: SphericalHarmonicSchema?
    ) throws -> ([GaussianSplat], [Float]) {
        // Get the body string
        let bodyData = data.suffix(from: bodyOffset)
        guard let bodyString = String(data: bodyData, encoding: .utf8) else {
            throw PLYError.invalidFormat("Cannot decode body as UTF-8")
        }

        let lines = bodyString.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var splats: [GaussianSplat] = []
        splats.reserveCapacity(element.count)
        var shCoefficients: [Float] = []
        if let shSchema {
            shCoefficients.reserveCapacity(element.count * shSchema.coefficientsPerSplat)
        }

        // Create property index map
        let propertyMap = createPropertyIndexMap(properties: element.properties)

        for line in lines.prefix(element.count) {
            let values = line.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            if values.isEmpty { continue }

            let splat = try parseGaussianFromValues(
                values: values,
                propertyMap: propertyMap,
                shSchema: shSchema,
                shCoefficients: &shCoefficients
            )
            splats.append(splat)
        }

        guard splats.count == element.count else {
            throw PLYError.invalidData("Expected \(element.count) Gaussian vertices, found \(splats.count)")
        }
        return (splats, shCoefficients)
    }

    // MARK: - Binary Parsing

    private static func parseBinaryGaussians(
        data: Data,
        bodyOffset: Int,
        element: PLYElement,
        bigEndian: Bool,
        shSchema: SphericalHarmonicSchema?
    ) throws -> ([GaussianSplat], [Float]) {
        var splats: [GaussianSplat] = []
        splats.reserveCapacity(element.count)
        var shCoefficients: [Float] = []
        if let shSchema {
            shCoefficients.reserveCapacity(element.count * shSchema.coefficientsPerSplat)
        }

        // Calculate stride for each vertex
        let stride = calculateStride(properties: element.properties)
        let propertyMap = createPropertyIndexMap(properties: element.properties)
        let propertyOffsets = calculatePropertyOffsets(properties: element.properties)

        var offset = bodyOffset

        for _ in 0 ..< element.count {
            guard offset + stride <= data.count else {
                throw PLYError.invalidFormat("Unexpected end of file")
            }

            let vertexData = data.subdata(in: offset ..< (offset + stride))
            let splat = try parseGaussianFromBinary(
                data: vertexData,
                properties: element.properties,
                propertyMap: propertyMap,
                propertyOffsets: propertyOffsets,
                bigEndian: bigEndian,
                shSchema: shSchema,
                shCoefficients: &shCoefficients
            )
            splats.append(splat)

            offset += stride
        }

        return (splats, shCoefficients)
    }

    // MARK: - Gaussian Parsing Helpers

    private static func createPropertyIndexMap(properties: [PLYProperty]) -> [String: Int] {
        var map: [String: Int] = [:]
        for (index, property) in properties.enumerated() {
            map[property.name] = index
        }
        return map
    }

    private struct SphericalHarmonicSchema {
        let degree: Int
        let coefficientsPerChannel: Int
        let restPropertyNames: [String]

        var coefficientsPerSplat: Int {
            coefficientsPerChannel * 3
        }
    }

    private static func sphericalHarmonicSchema(for properties: [PLYProperty]) throws -> SphericalHarmonicSchema? {
        let names = Set(properties.map(\.name))
        let dcNames = (0 ..< 3).map { "f_dc_\($0)" }
        let dcCount = dcNames.filter(names.contains).count
        let restProperties = properties.filter { $0.name.hasPrefix("f_rest_") }
        let parsedRestIndices = restProperties.map { Int($0.name.dropFirst("f_rest_".count)) }
        guard parsedRestIndices.allSatisfy({ $0 != nil }) else {
            throw PLYError.invalidData("f_rest_* properties must end in a numeric index")
        }
        let restIndices = parsedRestIndices.compactMap { $0 }.sorted()

        guard dcCount == 0 || dcCount == 3 else {
            throw PLYError.invalidData("Spherical harmonics require f_dc_0, f_dc_1, and f_dc_2")
        }
        guard dcCount == 3 || restIndices.isEmpty else {
            throw PLYError.invalidData("f_rest_* properties require all three f_dc_* properties")
        }
        guard dcCount == 3 else { return nil }

        guard restIndices == Array(0 ..< restIndices.count) else {
            throw PLYError.invalidData("f_rest_* property indices must be contiguous starting at zero")
        }

        let supportedRestCounts = [0: 0, 9: 1, 24: 2, 45: 3]
        guard let degree = supportedRestCounts[restIndices.count] else {
            throw PLYError.invalidData(
                "Unsupported spherical-harmonic coefficient count: \(restIndices.count) f_rest_* values"
            )
        }

        return SphericalHarmonicSchema(
            degree: degree,
            coefficientsPerChannel: (degree + 1) * (degree + 1),
            restPropertyNames: restIndices.map { "f_rest_\($0)" }
        )
    }

    private static func parseGaussianFromValues(
        values: [String],
        propertyMap: [String: Int],
        shSchema: SphericalHarmonicSchema?,
        shCoefficients: inout [Float]
    ) throws -> GaussianSplat {
        // Extract position
        let x = try getFloat(values: values, propertyMap: propertyMap, key: "x")
        let y = try getFloat(values: values, propertyMap: propertyMap, key: "y")
        let z = try getFloat(values: values, propertyMap: propertyMap, key: "z")

        // Extract scale (often stored as log scale in PLY)
        let scale0 = try getFloat(values: values, propertyMap: propertyMap, key: "scale_0", default: 0.0)
        let scale1 = try getFloat(values: values, propertyMap: propertyMap, key: "scale_1", default: 0.0)
        let scale2 = try getFloat(values: values, propertyMap: propertyMap, key: "scale_2", default: 0.0)

        // Convert from log scale to linear scale
        let scaleX = exp(scale0)
        let scaleY = exp(scale1)
        let scaleZ = exp(scale2)

        // Extract color (from spherical harmonics DC component or direct RGB)
        var r: Float, g: Float, b: Float
        if let shSchema {
            // Color from spherical harmonics
            let dcR = try getFloat(values: values, propertyMap: propertyMap, key: "f_dc_0")
            let dcG = try getFloat(values: values, propertyMap: propertyMap, key: "f_dc_1")
            let dcB = try getFloat(values: values, propertyMap: propertyMap, key: "f_dc_2")
            r = dcR
            g = dcG
            b = dcB

            // Convert from SH to RGB (DC component of SH corresponds to RGB / C0 where C0 = 0.28209479177387814)
            let C0: Float = 0.28209479177387814
            r = (r * C0 + 0.5)
            g = (g * C0 + 0.5)
            b = (b * C0 + 0.5)

            let dc = (dcR, dcG, dcB)
            let restPerChannel = shSchema.coefficientsPerChannel - 1
            for channel in 0 ..< 3 {
                shCoefficients.append(channel == 0 ? dc.0 : (channel == 1 ? dc.1 : dc.2))
                let start = channel * restPerChannel
                for index in start ..< start + restPerChannel {
                    try shCoefficients.append(
                        getFloat(
                            values: values,
                            propertyMap: propertyMap,
                            key: shSchema.restPropertyNames[index]
                        )
                    )
                }
            }
        } else {
            // Direct RGB
            r = try getFloat(values: values, propertyMap: propertyMap, key: "red", default: 1.0) / 255.0
            g = try getFloat(values: values, propertyMap: propertyMap, key: "green", default: 1.0) / 255.0
            b = try getFloat(values: values, propertyMap: propertyMap, key: "blue", default: 1.0) / 255.0
        }

        // Extract opacity (often stored as logit)
        let opacity = try getFloat(values: values, propertyMap: propertyMap, key: "opacity", default: 0.0)
        let alpha = 1.0 / (1.0 + exp(-opacity)) // Sigmoid to convert from logit to [0,1]

        // Extract rotation quaternion
        let rot0 = try getFloat(values: values, propertyMap: propertyMap, key: "rot_0", default: 1.0)
        let rot1 = try getFloat(values: values, propertyMap: propertyMap, key: "rot_1", default: 0.0)
        let rot2 = try getFloat(values: values, propertyMap: propertyMap, key: "rot_2", default: 0.0)
        let rot3 = try getFloat(values: values, propertyMap: propertyMap, key: "rot_3", default: 0.0)

        // Normalize quaternion
        let quat = simd_normalize(simd_float4(rot0, rot1, rot2, rot3))

        return GaussianSplat(
            center: simd_float4(x, y, z, 1.0),
            scale: simd_float4(scaleX, scaleY, scaleZ, 1.0),
            color: simd_float4(r, g, b, alpha),
            quat: quat,
            opacity: alpha
        )
    }

    private static func getFloat(values: [String], propertyMap: [String: Int], key: String, default defaultValue: Float? = nil) throws -> Float {
        guard let index = propertyMap[key] else {
            if let defaultValue {
                return defaultValue
            }
            throw PLYError.missingProperty(key)
        }
        guard index < values.count, let value = Float(values[index]) else {
            throw PLYError.invalidData("Cannot parse float for property '\(key)'")
        }
        return value
    }

    // MARK: - Binary Helpers

    private static func calculateStride(properties: [PLYProperty]) -> Int {
        var stride = 0
        for property in properties {
            if property.isList {
                // Lists are variable length, cannot be handled in fixed stride
                // For Gaussian splats, we typically don't have lists
                continue
            }
            stride += sizeOfType(property.type)
        }
        return stride
    }

    private static func calculatePropertyOffsets(properties: [PLYProperty]) -> [Int] {
        var offsets: [Int] = []
        var currentOffset = 0
        for property in properties {
            offsets.append(currentOffset)
            if !property.isList {
                currentOffset += sizeOfType(property.type)
            }
        }
        return offsets
    }

    private static func sizeOfType(_ type: String) -> Int {
        switch type {
        case "char", "uchar", "int8", "uint8":
            return 1
        case "short", "ushort", "int16", "uint16":
            return 2
        case "int", "uint", "float", "int32", "uint32", "float32":
            return 4
        case "double", "float64":
            return 8
        default:
            return 0
        }
    }

    private static func parseGaussianFromBinary(
        data: Data,
        properties: [PLYProperty],
        propertyMap: [String: Int],
        propertyOffsets: [Int],
        bigEndian: Bool,
        shSchema: SphericalHarmonicSchema?,
        shCoefficients: inout [Float]
    ) throws -> GaussianSplat {
        func readFloat(propertyName: String, default defaultValue: Float? = nil) throws -> Float {
            guard let index = propertyMap[propertyName] else {
                if let defaultValue {
                    return defaultValue
                }
                throw PLYError.missingProperty(propertyName)
            }

            let offset = propertyOffsets[index]
            let property = properties[index]
            let size = sizeOfType(property.type)

            guard offset + size <= data.count else {
                throw PLYError.invalidData("Buffer overflow reading '\(propertyName)'")
            }

            return try convertToFloat(
                data: data,
                offset: offset,
                type: property.type,
                bigEndian: bigEndian
            )
        }

        // Extract all properties
        let x = try readFloat(propertyName: "x")
        let y = try readFloat(propertyName: "y")
        let z = try readFloat(propertyName: "z")

        let scale0 = try readFloat(propertyName: "scale_0", default: 0.0)
        let scale1 = try readFloat(propertyName: "scale_1", default: 0.0)
        let scale2 = try readFloat(propertyName: "scale_2", default: 0.0)

        let scaleX = exp(scale0)
        let scaleY = exp(scale1)
        let scaleZ = exp(scale2)

        var r: Float, g: Float, b: Float
        if let shSchema {
            let dcR = try readFloat(propertyName: "f_dc_0")
            let dcG = try readFloat(propertyName: "f_dc_1")
            let dcB = try readFloat(propertyName: "f_dc_2")
            r = dcR
            g = dcG
            b = dcB

            let C0: Float = 0.28209479177387814
            r = (r * C0 + 0.5)
            g = (g * C0 + 0.5)
            b = (b * C0 + 0.5)

            let dc = (dcR, dcG, dcB)
            let restPerChannel = shSchema.coefficientsPerChannel - 1
            for channel in 0 ..< 3 {
                shCoefficients.append(channel == 0 ? dc.0 : (channel == 1 ? dc.1 : dc.2))
                let start = channel * restPerChannel
                for index in start ..< start + restPerChannel {
                    try shCoefficients.append(
                        readFloat(propertyName: shSchema.restPropertyNames[index])
                    )
                }
            }
        } else {
            r = try readFloat(propertyName: "red", default: 1.0) / 255.0
            g = try readFloat(propertyName: "green", default: 1.0) / 255.0
            b = try readFloat(propertyName: "blue", default: 1.0) / 255.0
        }

        let opacity = try readFloat(propertyName: "opacity", default: 0.0)
        let alpha = 1.0 / (1.0 + exp(-opacity))

        let rot0 = try readFloat(propertyName: "rot_0", default: 1.0)
        let rot1 = try readFloat(propertyName: "rot_1", default: 0.0)
        let rot2 = try readFloat(propertyName: "rot_2", default: 0.0)
        let rot3 = try readFloat(propertyName: "rot_3", default: 0.0)

        let quat = simd_normalize(simd_float4(rot0, rot1, rot2, rot3))

        return GaussianSplat(
            center: simd_float4(x, y, z, 1.0),
            scale: simd_float4(scaleX, scaleY, scaleZ, 1.0),
            color: simd_float4(r, g, b, alpha),
            quat: quat,
            opacity: alpha
        )
    }

    private static func convertToFloat(data: Data, offset: Int, type: String, bigEndian: Bool) throws -> Float {
        try data.withUnsafeBytes { bytes in
            switch type {
            case "float", "float32":
                var bits = bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
                if bigEndian { bits = UInt32(bigEndian: bits) }
                return Float(bitPattern: bits)

            case "double", "float64":
                var bits = bytes.loadUnaligned(fromByteOffset: offset, as: UInt64.self)
                if bigEndian { bits = UInt64(bigEndian: bits) }
                return Float(Double(bitPattern: bits))

            case "uchar", "uint8":
                return Float(bytes[offset])

            case "char", "int8":
                return Float(Int8(bitPattern: bytes[offset]))

            case "ushort", "uint16":
                var value = bytes.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
                if bigEndian { value = UInt16(bigEndian: value) }
                return Float(value)

            case "short", "int16":
                var value = bytes.loadUnaligned(fromByteOffset: offset, as: Int16.self)
                if bigEndian { value = Int16(bigEndian: value) }
                return Float(value)

            case "uint", "uint32":
                var value = bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
                if bigEndian { value = UInt32(bigEndian: value) }
                return Float(value)

            case "int", "int32":
                var value = bytes.loadUnaligned(fromByteOffset: offset, as: Int32.self)
                if bigEndian { value = Int32(bigEndian: value) }
                return Float(value)

            default:
                throw PLYError.unsupportedType(type)
            }
        }
    }
}

// MARK: - Errors

public enum PLYError: Error, CustomStringConvertible {
    case invalidFormat(String)
    case unsupportedFormat(String)
    case unsupportedType(String)
    case missingElement(String)
    case missingProperty(String)
    case invalidData(String)

    public var description: String {
        switch self {
        case let .invalidFormat(msg):
            return "Invalid PLY format: \(msg)"
        case let .unsupportedFormat(format):
            return "Unsupported PLY format: \(format)"
        case let .unsupportedType(type):
            return "Unsupported data type: \(type)"
        case let .missingElement(element):
            return "Missing required element: \(element)"
        case let .missingProperty(property):
            return "Missing required property: \(property)"
        case let .invalidData(msg):
            return "Invalid data: \(msg)"
        }
    }
}
