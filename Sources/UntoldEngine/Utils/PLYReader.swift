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

/// A splat's peak alpha (at its own center, where the Gaussian falloff is 1) equals its
/// opacity — see fragmentGaussianTBDRShader's `alpha = opacity * exp(power)`, power <= 0.
/// The shader itself discards any fragment below this same threshold, so a splat whose
/// opacity never reaches it can never contribute a visible pixel anywhere in its extent.
/// Dropping it here removes it from vertex shading, rasterization, and per-fragment ALU
/// entirely instead of paying that cost every frame only to discard the result — this is
/// a lossless cull (identical rendered image), not a quality/perf tradeoff. Shared by every
/// Gaussian source reader (PLY, SPZ, ...) so the cull threshold can't drift between formats.
let minRetainedGaussianOpacity: Float = 1.0 / 255.0

func filterNegligibleOpacityGaussianSplats(
    splats: [GaussianSplat],
    shCoefficients: [Float],
    coefficientsPerSplat: Int,
    sourceTag: String
) -> ([GaussianSplat], [Float]) {
    guard splats.contains(where: { $0.opacity < minRetainedGaussianOpacity }) else {
        return (splats, shCoefficients)
    }

    var keptSplats: [GaussianSplat] = []
    keptSplats.reserveCapacity(splats.count)
    var keptCoefficients: [Float] = []
    if coefficientsPerSplat > 0 {
        keptCoefficients.reserveCapacity(shCoefficients.count)
    }

    for (index, splat) in splats.enumerated() {
        guard splat.opacity >= minRetainedGaussianOpacity else { continue }
        keptSplats.append(splat)
        if coefficientsPerSplat > 0 {
            let start = index * coefficientsPerSplat
            keptCoefficients.append(contentsOf: shCoefficients[start ..< start + coefficientsPerSplat])
        }
    }

    logNegligibleOpacityCull(culled: splats.count - keptSplats.count, of: splats.count, sourceTag: sourceTag)
    return (keptSplats, keptCoefficients)
}

/// The one line every Gaussian source reader logs for the visibility cull.
func logNegligibleOpacityCull(culled: Int, of total: Int, sourceTag: String) {
    Logger.log(
        message: String(
            format: "[Gaussian][%@] Culled %d/%d splats below visibility threshold (opacity < %.4f)",
            sourceTag, culled, total, minRetainedGaussianOpacity
        ),
        category: LogCategory.gaussian.rawValue
    )
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

    /// Number of splats a Gaussian `.ply` declares, read from the header alone — cheap enough
    /// for a file browser to show before a cook, however large the body is.
    public static func readGaussianSplatCount(from url: URL) throws -> Int {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        // parseHeader scans at most the first 100 000 bytes for `end_header`.
        let prefix = try handle.read(upToCount: headerScanLimit) ?? Data()
        let (header, _) = try parseHeader(from: prefix)
        guard let vertexElement = header.elements.first(where: { $0.name == "vertex" }) else {
            throw PLYError.missingElement("vertex")
        }
        return vertexElement.count
    }

    /// Reads Gaussian geometry and preserves all spherical-harmonic coefficients.
    ///
    /// The body is streamed in bounded windows (`PLYGaussianSource`), so only the result is
    /// resident, never a copy of the file.
    public static func readGaussianAsset(from url: URL) throws -> GaussianSplatAsset {
        try readGaussianAsset(from: url, windowing: .production)
    }

    /// `readGaussianAsset(from:)` over windows of the given sizes — the seam through which
    /// tests stream a small fixture in many windows.
    static func readGaussianAsset(from url: URL, windowing: PLYGaussianSource.Windowing) throws -> GaussianSplatAsset {
        let source = try PLYGaussianSource(url: url, windowing: windowing)
        var splats: [GaussianSplat] = []
        splats.reserveCapacity(source.vertexCount)
        var coefficients: [Float] = []
        if let schema = source.shSchema {
            coefficients.reserveCapacity(source.vertexCount * schema.coefficientsPerSplat)
        }
        var culled = 0
        try source.forEachWindow { window in
            splats.append(contentsOf: window.splats)
            coefficients.append(contentsOf: window.shCoefficients)
            culled += window.culledCount
        }
        if culled > 0 {
            logNegligibleOpacityCull(culled: culled, of: source.vertexCount, sourceTag: "PLY")
        }
        let sphericalHarmonics = source.shSchema.map {
            GaussianSphericalHarmonics(
                degree: $0.degree,
                coefficientsPerChannel: $0.coefficientsPerChannel,
                coefficients: coefficients
            )
        }
        return GaussianSplatAsset(splats: splats, sphericalHarmonics: sphericalHarmonics)
    }

    /// Bounds of the splat centres a `.ply` would load — the same visibility cull as
    /// `readGaussianSplats`, so the box is the one that asset's splats span — from one streamed
    /// pass with nothing resident but the running box. What an editor's "recenter" needs from a
    /// multi-gigabyte capture without a second full parse. `nil` when no splat survives the cull.
    public static func readGaussianCenterBounds(from url: URL) throws -> (min: SIMD3<Float>, max: SIMD3<Float>)? {
        let source = try PLYGaussianSource(url: url)
        var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        var kept = 0
        try source.forEachWindow { window in
            for splat in window.splats {
                let center = SIMD3<Float>(splat.center.x, splat.center.y, splat.center.z)
                minimum = simd_min(minimum, center)
                maximum = simd_max(maximum, center)
            }
            kept += window.splats.count
        }
        guard kept > 0 else { return nil }
        return (minimum, maximum)
    }

    // MARK: - Header Parsing

    /// `parseHeader` scans at most this many bytes for `end_header`.
    static let headerScanLimit = 100_000

    static func parseHeader(from data: Data) throws -> (PLYHeader, Int) {
        var header = PLYHeader(format: .ascii, version: "1.0", elements: [], comments: [])

        // Read header line by line until we find binary data
        var bodyOffset = 0
        var currentElement: PLYElement?
        var headerLines: [String] = []

        // Read the header byte by byte, line by line
        var lineStart = 0
        for i in 0 ..< min(data.count, headerScanLimit) {
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

    // MARK: - Spherical-harmonic schema

    struct SphericalHarmonicSchema {
        let degree: Int
        let coefficientsPerChannel: Int
        let restPropertyNames: [String]

        var coefficientsPerSplat: Int {
            coefficientsPerChannel * 3
        }

        /// `f_rest_*` values per channel.
        var restPerChannel: Int {
            coefficientsPerChannel - 1
        }
    }

    static func sphericalHarmonicSchema(for properties: [PLYProperty]) throws -> SphericalHarmonicSchema? {
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

    // MARK: - Per-vertex arithmetic

    /// The importer's splat from its raw PLY fields: log scales through `exp`, the SH DC term to
    /// a display colour (`0.5 + C0 × dc`), the logit opacity through a sigmoid, the quaternion
    /// normalised in the PLY order `(w, x, y, z)`. One function for the ASCII and binary bodies,
    /// so the two formats cannot drift.
    @inline(__always)
    static func makeSplat(_ v: PLYVertexFields) -> GaussianSplat {
        let scaleX = exp(v.scale0)
        let scaleY = exp(v.scale1)
        let scaleZ = exp(v.scale2)

        var r: Float, g: Float, b: Float
        if v.hasSphericalHarmonics {
            r = v.color0
            g = v.color1
            b = v.color2
            // Convert from SH to RGB (DC component of SH corresponds to RGB / C0 where C0 = 0.28209479177387814)
            let C0: Float = 0.28209479177387814
            r = (r * C0 + 0.5)
            g = (g * C0 + 0.5)
            b = (b * C0 + 0.5)
        } else {
            r = v.color0 / 255.0
            g = v.color1 / 255.0
            b = v.color2 / 255.0
        }

        let alpha = 1.0 / (1.0 + exp(-v.opacity)) // Sigmoid to convert from logit to [0,1]
        let quat = simd_normalize(simd_float4(v.rot0, v.rot1, v.rot2, v.rot3))

        return GaussianSplat(
            center: simd_float4(v.x, v.y, v.z, 1.0),
            scale: simd_float4(scaleX, scaleY, scaleZ, 1.0),
            color: simd_float4(r, g, b, alpha),
            quat: quat,
            opacity: alpha
        )
    }

    // MARK: - Binary Helpers

    static func sizeOfType(_ type: String) -> Int {
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

    static func scalarKind(_ type: String) -> PLYScalarKind? {
        switch type {
        case "float", "float32": .float32
        case "double", "float64": .float64
        case "uchar", "uint8": .uint8
        case "char", "int8": .int8
        case "ushort", "uint16": .uint16
        case "short", "int16": .int16
        case "uint", "uint32": .uint32
        case "int", "int32": .int32
        default: nil
        }
    }
}

/// The raw per-vertex fields `PLYReader.makeSplat` turns into a splat.
struct PLYVertexFields {
    var x: Float = 0, y: Float = 0, z: Float = 0
    var scale0: Float = 0, scale1: Float = 0, scale2: Float = 0
    /// `f_dc_*` with `hasSphericalHarmonics`, `red`/`green`/`blue` (0…255) without.
    var color0: Float = 0, color1: Float = 0, color2: Float = 0
    var hasSphericalHarmonics = false
    var opacity: Float = 0
    var rot0: Float = 1, rot1: Float = 0, rot2: Float = 0, rot3: Float = 0
}

/// The scalar types a binary body can carry, decoded to `Float` exactly as the importer always did.
enum PLYScalarKind {
    case float32, float64, uint8, int8, uint16, int16, uint32, int32

    var size: Int {
        switch self {
        case .uint8, .int8: 1
        case .uint16, .int16: 2
        case .float32, .uint32, .int32: 4
        case .float64: 8
        }
    }
}

/// Where a needed property's value comes from: a byte offset in a binary vertex, a column of an
/// ASCII line, a default for an optional property the file leaves out, or nothing (a required
/// property the file lacks — reported at the first vertex, as the importer always did).
enum PLYFieldSource {
    case binary(offset: Int, kind: PLYScalarKind)
    case column(Int)
    case constant(Float)
    case missing(name: String)
    /// A property present in the header whose type the binary reader cannot decode.
    case unsupportedType(String)
}

/// The vertex element's properties resolved once per file into typed sources, in the order the
/// importer evaluates them: position, scales, colour (SH DC or RGB), the `f_rest_*` terms in
/// schema order, opacity, rotation.
struct PLYVertexLayout {
    var x: PLYFieldSource, y: PLYFieldSource, z: PLYFieldSource
    var scale0: PLYFieldSource, scale1: PLYFieldSource, scale2: PLYFieldSource
    var color0: PLYFieldSource, color1: PLYFieldSource, color2: PLYFieldSource
    var rest: [PLYFieldSource]
    var opacity: PLYFieldSource
    var rot0: PLYFieldSource, rot1: PLYFieldSource, rot2: PLYFieldSource, rot3: PLYFieldSource
    /// Bytes per binary vertex (list and unknown-typed properties count as zero, as before).
    var stride: Int
    var hasSphericalHarmonics: Bool
    var bigEndian: Bool

    init(properties: [PLYProperty], format: PLYFormat, shSchema: PLYReader.SphericalHarmonicSchema?) {
        var indexByName: [String: Int] = [:]
        for (index, property) in properties.enumerated() {
            indexByName[property.name] = index
        }
        var offsets: [Int] = []
        var stride = 0
        for property in properties {
            offsets.append(stride)
            if !property.isList {
                stride += PLYReader.sizeOfType(property.type)
            }
        }
        self.stride = stride
        bigEndian = format == .binaryBigEndian
        hasSphericalHarmonics = shSchema != nil

        func source(_ name: String, default defaultValue: Float? = nil) -> PLYFieldSource {
            guard let index = indexByName[name] else {
                if let defaultValue { return .constant(defaultValue) }
                return .missing(name: name)
            }
            switch format {
            case .ascii:
                return .column(index)
            case .binaryLittleEndian, .binaryBigEndian:
                guard let kind = PLYReader.scalarKind(properties[index].type) else {
                    return .unsupportedType(properties[index].type)
                }
                return .binary(offset: offsets[index], kind: kind)
            }
        }

        x = source("x")
        y = source("y")
        z = source("z")
        scale0 = source("scale_0", default: 0.0)
        scale1 = source("scale_1", default: 0.0)
        scale2 = source("scale_2", default: 0.0)
        if let shSchema {
            color0 = source("f_dc_0")
            color1 = source("f_dc_1")
            color2 = source("f_dc_2")
            rest = shSchema.restPropertyNames.map { source($0) }
        } else {
            color0 = source("red", default: 1.0)
            color1 = source("green", default: 1.0)
            color2 = source("blue", default: 1.0)
            rest = []
        }
        opacity = source("opacity", default: 0.0)
        rot0 = source("rot_0", default: 1.0)
        rot1 = source("rot_1", default: 0.0)
        rot2 = source("rot_2", default: 0.0)
        rot3 = source("rot_3", default: 0.0)
    }

    /// The sources in evaluation order, so the first fault a vertex would hit is the one reported.
    var evaluationOrder: [PLYFieldSource] {
        var order = [x, y, z, scale0, scale1, scale2, color0, color1, color2]
        order.append(contentsOf: rest)
        order.append(contentsOf: [opacity, rot0, rot1, rot2, rot3])
        return order
    }

    /// The error every vertex of a binary body would raise, if any — a required property the
    /// header lacks or a type the reader cannot decode — in the importer's evaluation order.
    var constantBinaryFault: PLYError? {
        for source in evaluationOrder {
            switch source {
            case let .missing(name): return .missingProperty(name)
            case let .unsupportedType(type): return .unsupportedType(type)
            case .binary, .column, .constant: continue
            }
        }
        return nil
    }
}

/// One window of a streamed `.ply` body: the splats that survive the visibility cull, their
/// spherical harmonics in the importer's channel-major layout (DC first) at the source degree,
/// and how many vertices the cull dropped.
struct PLYGaussianWindow {
    var splats: [GaussianSplat]
    var shCoefficients: [Float]
    var culledCount: Int
}

/// A Gaussian `.ply` open for streamed reading: the header parsed once, the vertex properties
/// resolved into a typed layout, and the body served as bounded windows parsed in parallel and
/// handed over in source order. Nothing of the body is resident beyond one batch of windows.
final class PLYGaussianSource: @unchecked Sendable {
    let url: URL
    let header: PLYHeader
    let vertexElement: PLYElement
    let shSchema: PLYReader.SphericalHarmonicSchema?
    let layout: PLYVertexLayout
    let bodyOffset: Int
    let fileSize: Int
    private let file: OpenFile
    private var descriptor: Int32 {
        file.descriptor
    }

    /// Vertices the header declares.
    var vertexCount: Int {
        vertexElement.count
    }

    /// Body bytes, for progress.
    var bodyByteCount: Int {
        max(0, fileSize - bodyOffset)
    }

    /// How the body is cut into windows. Production's sizes unless a test asks for smaller
    /// ones, to run a fixture of a few hundred vertices through many windows.
    struct Windowing {
        /// Bytes of source a binary window covers, before rounding to whole vertices. Small
        /// enough that a batch of windows — the raw bytes, the parsed splats and harmonics, the
        /// cooked store — stays under about 100 MB across every core: malloc keeps what a batch
        /// frees cached and dirty, so the batch size is footprint for the rest of the bake.
        var targetWindowBytes = 2 << 20
        /// Bytes of text an ASCII window covers, before cutting at a line boundary.
        var asciiWindowBytes = 2 << 20
        /// The fewest vertices a binary window holds, however wide the vertex.
        var minVerticesPerWindow = 1024

        static let production = Windowing()
    }

    let windowing: Windowing

    /// Windows read by the last `forEachWindow`, including an ASCII body's past the declared
    /// count. For tests, which prove a fixture went through more than one.
    private(set) var windowsRead = 0

    /// A read-only descriptor closed exactly once, whenever the source goes away — including
    /// when `init` throws part-way.
    private final class OpenFile: @unchecked Sendable {
        let descriptor: Int32

        init(path: String) throws {
            let descriptor = open(path, O_RDONLY)
            guard descriptor >= 0 else {
                throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileReadNoSuchFile.rawValue, userInfo: [NSFilePathErrorKey: path])
            }
            self.descriptor = descriptor
        }

        deinit {
            close(descriptor)
        }
    }

    init(url: URL, windowing: Windowing = .production) throws {
        self.url = url
        self.windowing = windowing
        let file = try OpenFile(path: url.path)
        self.file = file
        var info = stat()
        guard fstat(file.descriptor, &info) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSFilePathErrorKey: url.path])
        }
        fileSize = Int(info.st_size)

        var prefix = [UInt8](repeating: 0, count: min(fileSize, PLYReader.headerScanLimit))
        try Self.read(file.descriptor, into: &prefix, count: prefix.count, at: 0)
        let (header, bodyOffset) = try PLYReader.parseHeader(from: Data(prefix))
        self.header = header
        self.bodyOffset = bodyOffset

        guard let vertexElement = header.elements.first(where: { $0.name == "vertex" }) else {
            throw PLYError.missingElement("vertex")
        }
        self.vertexElement = vertexElement
        shSchema = try PLYReader.sphericalHarmonicSchema(for: vertexElement.properties)
        layout = PLYVertexLayout(properties: vertexElement.properties, format: header.format, shSchema: shSchema)

        // A binary body's faults are the same for every vertex; report them as the first vertex
        // would have: a truncated first vertex first, then a missing or undecodable property,
        // then a body shorter than its count.
        if header.format != .ascii, vertexElement.count > 0 {
            guard bodyOffset + layout.stride <= fileSize else {
                throw PLYError.invalidFormat("Unexpected end of file")
            }
            if let fault = layout.constantBinaryFault {
                throw fault
            }
            guard bodyOffset + vertexElement.count * layout.stride <= fileSize else {
                throw PLYError.invalidFormat("Unexpected end of file")
            }
        }
    }

    /// `count` bytes at `offset`, or `.invalidFormat` when the file ends first.
    private static func read(_ descriptor: Int32, into buffer: inout [UInt8], count: Int, at offset: Int) throws {
        guard count > 0 else { return }
        try buffer.withUnsafeMutableBytes { raw in
            var done = 0
            while done < count {
                let got = pread(descriptor, raw.baseAddress! + done, count - done, off_t(offset + done))
                if got < 0 {
                    if errno == EINTR { continue }
                    throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
                }
                guard got > 0 else {
                    throw PLYError.invalidFormat("Unexpected end of file")
                }
                done += got
            }
        }
    }

    // MARK: - Windows

    /// A window's byte range and, for a binary body, its vertex range.
    private struct WindowRange {
        var byteOffset: Int
        var byteCount: Int
        var firstVertex: Int
        var vertexCount: Int
    }

    /// The binary body cut into whole-vertex windows of about `windowing.targetWindowBytes`.
    private func binaryWindows() -> [WindowRange] {
        let count = vertexElement.count
        guard count > 0 else { return [] }
        let stride = layout.stride
        let perWindow = stride > 0 ? max(windowing.minVerticesPerWindow, min(1 << 20, windowing.targetWindowBytes / stride)) : count
        var windows: [WindowRange] = []
        var first = 0
        while first < count {
            let n = min(perWindow, count - first)
            windows.append(WindowRange(byteOffset: bodyOffset + first * stride, byteCount: n * stride, firstVertex: first, vertexCount: n))
            first += n
        }
        return windows
    }

    /// The ASCII body cut at line boundaries into windows of about `windowing.asciiWindowBytes`,
    /// found by probing for the newline after each boundary rather than scanning the body.
    private func asciiWindows() throws -> [WindowRange] {
        var windows: [WindowRange] = []
        var start = bodyOffset
        let end = fileSize
        while start < end {
            var cut = min(start + windowing.asciiWindowBytes, end)
            if cut < end {
                // Extend to just past the first newline at or after the estimate.
                var probeOffset = cut
                var found: Int?
                var probe = [UInt8](repeating: 0, count: 1 << 16)
                while found == nil, probeOffset < end {
                    let n = min(probe.count, end - probeOffset)
                    try Self.read(descriptor, into: &probe, count: n, at: probeOffset)
                    if let index = probe[0 ..< n].firstIndex(of: 0x0A) {
                        found = probeOffset + index + 1
                    } else {
                        probeOffset += n
                    }
                }
                cut = found ?? end
            }
            windows.append(WindowRange(byteOffset: start, byteCount: cut - start, firstVertex: 0, vertexCount: 0))
            start = cut
        }
        return windows
    }

    /// Runs `body` on every window of the file in source order. Windows are read and parsed in
    /// parallel, `parallelism` at a time; `body` and `afterBatch` run on the calling thread, the
    /// latter after every batch with the fraction of the body consumed so far — the place for
    /// progress and cancellation. A parse error surfaces after the windows before it were
    /// delivered, so a consumer never sees a window out of order.
    func forEachWindow(
        parallelism: Int = ProcessInfo.processInfo.activeProcessorCount,
        afterBatch: (Double) throws -> Void = { _ in },
        body: (PLYGaussianWindow) throws -> Void
    ) throws {
        try forEachWindow(parallelism: parallelism, map: { $0 }, afterBatch: afterBatch, body: body)
    }

    /// `forEachWindow` with a `map` step that runs inside the parallel work item — the place for
    /// per-splat work that must not serialise on the delivering thread (the cook). For an ASCII
    /// body, whose windows are cut to the vertex count only once the lines before them are
    /// counted, `map` runs on the delivering thread instead.
    func forEachWindow<Mapped>(
        parallelism: Int = ProcessInfo.processInfo.activeProcessorCount,
        map: @Sendable @escaping (PLYGaussianWindow) throws -> Mapped,
        afterBatch: (Double) throws -> Void = { _ in },
        body: (Mapped) throws -> Void
    ) throws {
        switch header.format {
        case .ascii:
            try forEachASCIIWindow(parallelism: parallelism, afterBatch: afterBatch) { window in
                try body(map(window))
            }
        case .binaryLittleEndian, .binaryBigEndian:
            try forEachBinaryWindow(parallelism: parallelism, map: map, afterBatch: afterBatch, body: body)
        }
    }

    private func forEachBinaryWindow<Mapped>(
        parallelism: Int,
        map: @Sendable @escaping (PLYGaussianWindow) throws -> Mapped,
        afterBatch: (Double) throws -> Void,
        body: (Mapped) throws -> Void
    ) throws {
        let windows = binaryWindows()
        let batchSize = max(1, parallelism)
        var consumed = 0
        var start = 0
        windowsRead = 0
        while start < windows.count {
            let batch = Array(windows[start ..< min(start + batchSize, windows.count)])
            let results = ParallelResults<Mapped>(count: batch.count)
            DispatchQueue.concurrentPerform(iterations: batch.count) { slot in
                do {
                    let window = batch[slot]
                    var buffer = [UInt8](repeating: 0, count: window.byteCount)
                    try Self.read(descriptor, into: &buffer, count: window.byteCount, at: window.byteOffset)
                    let mapped = try map(parseBinary(buffer, vertexCount: window.vertexCount))
                    results.store(mapped, at: slot)
                } catch {
                    results.fail(error, at: slot)
                }
            }
            for slot in batch.indices {
                try body(results.take(slot))
                consumed += batch[slot].byteCount
                windowsRead += 1
            }
            start += batch.count
            try afterBatch(bodyByteCount > 0 ? Double(consumed) / Double(bodyByteCount) : 1)
        }
    }

    private func forEachASCIIWindow(parallelism: Int, afterBatch: (Double) throws -> Void, body: (PLYGaussianWindow) throws -> Void) throws {
        let windows = try asciiWindows()
        let batchSize = max(1, parallelism)
        let limit = vertexElement.count
        var linesBefore = 0
        var consumed = 0
        var splatsSoFar = 0
        var start = 0
        windowsRead = 0
        while start < windows.count {
            let batch = Array(windows[start ..< min(start + batchSize, windows.count)])
            // Once the declared count is met the rest of the body is only checked for UTF-8, as
            // decoding the whole body used to.
            let parseLines = linesBefore < limit
            let results = ParallelResults<ASCIIWindow>(count: batch.count)
            DispatchQueue.concurrentPerform(iterations: batch.count) { slot in
                do {
                    let window = batch[slot]
                    var buffer = [UInt8](repeating: 0, count: window.byteCount)
                    try Self.read(descriptor, into: &buffer, count: window.byteCount, at: window.byteOffset)
                    let parsed = try parseASCII(buffer, parseLines: parseLines)
                    results.store(parsed, at: slot)
                } catch {
                    results.fail(error, at: slot)
                }
            }
            for slot in batch.indices {
                let parsed = try results.take(slot)
                let allowed = limit - linesBefore
                if allowed > 0 {
                    if let fault = parsed.firstFault, fault.line < allowed {
                        throw fault.error
                    }
                    var window = PLYGaussianWindow(splats: [], shCoefficients: [], culledCount: 0)
                    window.splats.reserveCapacity(parsed.lineOfSplat.count)
                    let perSplat = shSchema?.coefficientsPerSplat ?? 0
                    for (index, line) in parsed.lineOfSplat.enumerated() where line < allowed {
                        let splat = parsed.splats[index]
                        splatsSoFar += 1
                        guard splat.opacity >= minRetainedGaussianOpacity else {
                            window.culledCount += 1
                            continue
                        }
                        window.splats.append(splat)
                        if perSplat > 0 {
                            window.shCoefficients.append(contentsOf: parsed.shCoefficients[index * perSplat ..< (index + 1) * perSplat])
                        }
                    }
                    try body(window)
                }
                linesBefore += parsed.lineCount
                consumed += batch[slot].byteCount
                windowsRead += 1
            }
            start += batch.count
            try afterBatch(bodyByteCount > 0 ? Double(consumed) / Double(bodyByteCount) : 1)
        }
        guard splatsSoFar == limit else {
            throw PLYError.invalidData("Expected \(limit) Gaussian vertices, found \(splatsSoFar)")
        }
    }

    // MARK: - Binary parsing

    private func parseBinary(_ buffer: [UInt8], vertexCount: Int) -> PLYGaussianWindow {
        var window = PLYGaussianWindow(splats: [], shCoefficients: [], culledCount: 0)
        window.splats.reserveCapacity(vertexCount)
        let layout = layout
        let stride = layout.stride
        let bigEndian = layout.bigEndian
        let restCount = layout.rest.count
        let perChannel = shSchema?.coefficientsPerChannel ?? 0
        let restPerChannel = shSchema?.restPerChannel ?? 0
        if let shSchema {
            window.shCoefficients.reserveCapacity(vertexCount * shSchema.coefficientsPerSplat)
        }

        // The layout's sources are read through pointers: the `rest` array is shared by every
        // window in flight, and an array subscript in an unoptimised build would retain and
        // release that shared buffer from sixteen threads at once, per field.
        let restSources = layout.rest
        restSources.withUnsafeBufferPointer { rest in
            buffer.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return }
                var restValues = [Float](repeating: 0, count: restCount)
                for vertex in 0 ..< vertexCount {
                    let p = base + vertex * stride
                    var fields = PLYVertexFields()
                    fields.hasSphericalHarmonics = layout.hasSphericalHarmonics
                    fields.x = Self.load(p, layout.x, bigEndian)
                    fields.y = Self.load(p, layout.y, bigEndian)
                    fields.z = Self.load(p, layout.z, bigEndian)
                    fields.scale0 = Self.load(p, layout.scale0, bigEndian)
                    fields.scale1 = Self.load(p, layout.scale1, bigEndian)
                    fields.scale2 = Self.load(p, layout.scale2, bigEndian)
                    fields.color0 = Self.load(p, layout.color0, bigEndian)
                    fields.color1 = Self.load(p, layout.color1, bigEndian)
                    fields.color2 = Self.load(p, layout.color2, bigEndian)
                    restValues.withUnsafeMutableBufferPointer { restValues in
                        for index in 0 ..< restCount {
                            restValues[index] = Self.load(p, rest[index], bigEndian)
                        }
                    }
                    fields.opacity = Self.load(p, layout.opacity, bigEndian)
                    fields.rot0 = Self.load(p, layout.rot0, bigEndian)
                    fields.rot1 = Self.load(p, layout.rot1, bigEndian)
                    fields.rot2 = Self.load(p, layout.rot2, bigEndian)
                    fields.rot3 = Self.load(p, layout.rot3, bigEndian)

                    let splat = PLYReader.makeSplat(fields)
                    guard splat.opacity >= minRetainedGaussianOpacity else {
                        window.culledCount += 1
                        continue
                    }
                    window.splats.append(splat)
                    if perChannel > 0 {
                        Self.appendSphericalHarmonics(&window.shCoefficients, dc: (fields.color0, fields.color1, fields.color2), rest: restValues, restPerChannel: restPerChannel)
                    }
                }
            }
        }
        return window
    }

    /// The importer's channel-major SH layout: each channel's DC term, then its `f_rest_*` terms.
    @inline(__always)
    static func appendSphericalHarmonics(_ coefficients: inout [Float], dc: (Float, Float, Float), rest: [Float], restPerChannel: Int) {
        for channel in 0 ..< 3 {
            coefficients.append(channel == 0 ? dc.0 : (channel == 1 ? dc.1 : dc.2))
            let start = channel * restPerChannel
            for index in start ..< start + restPerChannel {
                coefficients.append(rest[index])
            }
        }
    }

    /// One binary field, decoded as `convertToFloat` always did: floats by bit pattern (doubles
    /// through `Double`), integers through `Float(_:)`.
    @inline(__always)
    private static func load(_ vertex: UnsafeRawPointer, _ source: PLYFieldSource, _ bigEndian: Bool) -> Float {
        switch source {
        case let .binary(offset, kind):
            let p = vertex + offset
            switch kind {
            case .float32:
                var bits = p.loadUnaligned(as: UInt32.self)
                if bigEndian { bits = UInt32(bigEndian: bits) }
                return Float(bitPattern: bits)
            case .float64:
                var bits = p.loadUnaligned(as: UInt64.self)
                if bigEndian { bits = UInt64(bigEndian: bits) }
                return Float(Double(bitPattern: bits))
            case .uint8:
                return Float(p.load(as: UInt8.self))
            case .int8:
                return Float(Int8(bitPattern: p.load(as: UInt8.self)))
            case .uint16:
                var value = p.loadUnaligned(as: UInt16.self)
                if bigEndian { value = UInt16(bigEndian: value) }
                return Float(value)
            case .int16:
                var value = p.loadUnaligned(as: Int16.self)
                if bigEndian { value = Int16(bigEndian: value) }
                return Float(value)
            case .uint32:
                var value = p.loadUnaligned(as: UInt32.self)
                if bigEndian { value = UInt32(bigEndian: value) }
                return Float(value)
            case .int32:
                var value = p.loadUnaligned(as: Int32.self)
                if bigEndian { value = Int32(bigEndian: value) }
                return Float(value)
            }
        case let .constant(value):
            return value
        case .column, .missing, .unsupportedType:
            // Ruled out for a binary body by `constantBinaryFault` before any window is read.
            return 0
        }
    }

    // MARK: - ASCII parsing

    /// The lines of one ASCII window, parsed before the vertex count is applied: every splat
    /// with the window-relative index of its line, the first line that failed (later lines are
    /// not parsed; they are beyond it whatever the count), and the window's line count.
    private struct ASCIIWindow {
        var splats: [GaussianSplat] = []
        var shCoefficients: [Float] = []
        var lineOfSplat: [Int] = []
        var lineCount = 0
        var firstFault: (line: Int, error: Error)?
    }

    private func parseASCII(_ buffer: [UInt8], parseLines: Bool) throws -> ASCIIWindow {
        guard let text = String(bytes: buffer, encoding: .utf8) else {
            throw PLYError.invalidFormat("Cannot decode body as UTF-8")
        }
        var window = ASCIIWindow()
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        window.lineCount = lines.count
        guard parseLines else { return window }

        let layout = layout
        let restCount = layout.rest.count
        let restPerChannel = shSchema?.restPerChannel ?? 0
        var restValues = [Float](repeating: 0, count: restCount)
        for (line, lineText) in lines.enumerated() {
            let values = lineText.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            if values.isEmpty { continue }

            do {
                var fields = PLYVertexFields()
                fields.hasSphericalHarmonics = layout.hasSphericalHarmonics
                fields.x = try Self.parse(values, layout.x, "x")
                fields.y = try Self.parse(values, layout.y, "y")
                fields.z = try Self.parse(values, layout.z, "z")
                fields.scale0 = try Self.parse(values, layout.scale0, "scale_0")
                fields.scale1 = try Self.parse(values, layout.scale1, "scale_1")
                fields.scale2 = try Self.parse(values, layout.scale2, "scale_2")
                if let shSchema {
                    fields.color0 = try Self.parse(values, layout.color0, "f_dc_0")
                    fields.color1 = try Self.parse(values, layout.color1, "f_dc_1")
                    fields.color2 = try Self.parse(values, layout.color2, "f_dc_2")
                    for index in 0 ..< restCount {
                        restValues[index] = try Self.parse(values, layout.rest[index], shSchema.restPropertyNames[index])
                    }
                } else {
                    fields.color0 = try Self.parse(values, layout.color0, "red")
                    fields.color1 = try Self.parse(values, layout.color1, "green")
                    fields.color2 = try Self.parse(values, layout.color2, "blue")
                }
                fields.opacity = try Self.parse(values, layout.opacity, "opacity")
                fields.rot0 = try Self.parse(values, layout.rot0, "rot_0")
                fields.rot1 = try Self.parse(values, layout.rot1, "rot_1")
                fields.rot2 = try Self.parse(values, layout.rot2, "rot_2")
                fields.rot3 = try Self.parse(values, layout.rot3, "rot_3")

                window.splats.append(PLYReader.makeSplat(fields))
                window.lineOfSplat.append(line)
                if shSchema != nil {
                    Self.appendSphericalHarmonics(&window.shCoefficients, dc: (fields.color0, fields.color1, fields.color2), rest: restValues, restPerChannel: restPerChannel)
                }
            } catch {
                window.firstFault = (line, error)
                break
            }
        }
        return window
    }

    /// One ASCII field: `Float(_:)` on its column, the default for an optional property the
    /// header lacks, `.missingProperty` for a required one.
    @inline(__always)
    private static func parse(_ values: [String], _ source: PLYFieldSource, _ key: String) throws -> Float {
        switch source {
        case let .column(index):
            guard index < values.count, let value = Float(values[index]) else {
                throw PLYError.invalidData("Cannot parse float for property '\(key)'")
            }
            return value
        case let .constant(value):
            return value
        case let .missing(name):
            throw PLYError.missingProperty(name)
        case let .unsupportedType(type):
            throw PLYError.unsupportedType(type)
        case .binary:
            return 0
        }
    }
}

/// Per-slot results of a `concurrentPerform` batch, handed back in slot order.
final class ParallelResults<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Value?]
    private var errors: [Error?]

    init(count: Int) {
        values = [Value?](repeating: nil, count: count)
        errors = [Error?](repeating: nil, count: count)
    }

    func store(_ value: Value, at slot: Int) {
        lock.withLock { values[slot] = value }
    }

    func fail(_ error: Error, at slot: Int) {
        lock.withLock { errors[slot] = error }
    }

    /// The slot's value, released from the results; its error if it failed.
    func take(_ slot: Int) throws -> Value {
        try lock.withLock {
            if let error = errors[slot] {
                throw error
            }
            guard let value = values[slot] else {
                throw UntoldGSError.invalidInput("parallel slot \(slot) produced no result")
            }
            values[slot] = nil
            return value
        }
    }

    /// The first failure in slot order, if any.
    var firstError: Error? {
        lock.withLock { errors.compactMap { $0 }.first }
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
