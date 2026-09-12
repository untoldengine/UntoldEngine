//
//  UntoldGSCookerEquivalenceTests.swift
//  UntoldEngineTests
//
//  Pins the streamed cook (windows → store → parallel writer) to the bytes of
//  the whole-array path it replaced: the same .ply cooked both ways is the
//  same file, byte for byte, for single- and two-tier bakes, and the outputs
//  carry SHA-256 pins so both paths cannot drift together — through
//  production's windows and through windows small enough that the fixtures
//  span many of them. Also the progress and cancellation contract of
//  UntoldGSCookControl, and the streamed centre bounds against the loaded
//  splats.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CryptoKit
import CShaderTypes
import simd
@testable import UntoldEngine
import XCTest

final class UntoldGSCookerEquivalenceTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("UntoldGSCookerEquivalenceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        super.tearDown()
    }

    // MARK: - Fixtures

    /// The cooker test's 300-splat ASCII grid: SH degree 1, `nx ny nz` to skip. `declaredCount`
    /// is what the header claims when it is not the line count; `unreadableLines` are replaced
    /// by a face-shaped line no vertex parse accepts.
    private func asciiFixture(lineCount: Int = 300, declaredCount: Int? = nil, unreadableLines: Set<Int> = []) throws -> URL {
        var body = ""
        for index in 0 ..< lineCount {
            guard !unreadableLines.contains(index) else {
                body += "3 \(index) \(index + 1) \(index + 2)\n"
                continue
            }
            let x = Float(index % 10) * 0.1
            let y = Float(index / 10 % 10) * 0.1
            let z = Float(index / 100) * 0.1
            let rest = (0 ..< 9).map { "\(Float($0) * 0.01)" }.joined(separator: " ")
            body += "\(x) \(y) \(z) 0 0 1 0.2 0.1 -0.1 \(rest) 2.0 -4 -4 -4 1 0 0 0\n"
        }
        let header = """
        ply
        format ascii 1.0
        element vertex \(declaredCount ?? lineCount)
        property float x
        property float y
        property float z
        property float nx
        property float ny
        property float nz
        property float f_dc_0
        property float f_dc_1
        property float f_dc_2
        \((0 ..< 9).map { "property float f_rest_\($0)" }.joined(separator: "\n"))
        property float opacity
        property float scale_0
        property float scale_1
        property float scale_2
        property float rot_0
        property float rot_1
        property float rot_2
        property float rot_3
        end_header
        """
        let url = temporaryDirectory.appendingPathComponent("grid.ply")
        try Data((header + "\n" + body).utf8).write(to: url)
        return url
    }

    /// A deterministic 1100-splat binary SH3 capture in the 3DGS property order plus a `uchar`
    /// property to skip: opacities across the visibility cull (1/255) and the cook floor (0.005),
    /// one degenerate splat (a −∞ log scale), higher-order terms past the ±1 quantisation range,
    /// and a trailing `face` element. Little-endian unless asked otherwise; the same values
    /// either way.
    private func binaryFixture(bigEndian: Bool = false) throws -> URL {
        let count = 1100
        var rng = SplitMix64(seed: 0x5EED_5EED_1100)
        var ply = PLYBinaryBuilder(bigEndian: bigEndian, comment: "synthetic SH3 capture")
        for name in ["x", "y", "z", "nx", "ny", "nz", "f_dc_0", "f_dc_1", "f_dc_2"] {
            ply.property(name, .float)
        }
        for term in 0 ..< 45 {
            ply.property("f_rest_\(term)", .float)
        }
        for name in ["opacity", "scale_0", "scale_1", "scale_2", "rot_0", "rot_1", "rot_2", "rot_3"] {
            ply.property(name, .float)
        }
        ply.property("tag", .uchar)
        ply.beginBody(vertexCount: count, trailingFaceElement: true)

        for index in 0 ..< count {
            // A disc-ish cloud with a few outliers, so the crop and the Morton order both bite.
            let radius = rng.unit() * (index % 97 == 0 ? 6 : 2)
            let angle = rng.unit() * 2 * .pi
            ply.append(radius * cos(angle))
            ply.append(rng.unit() * 0.3 - 0.15)
            ply.append(radius * sin(angle))
            ply.append(0)
            ply.append(0)
            ply.append(1)
            for _ in 0 ..< 3 {
                ply.append(rng.unit() * 2 - 1)
            }
            for term in 0 ..< 45 {
                let value = rng.unit() - 0.5
                ply.append(index % 131 == 7 && term % 11 == 0 ? value * 4 : value)
            }
            // Opacity logits: most visible, some between the cull and the cook floor, some below.
            switch index % 53 {
            case 0: ply.append(-7) // sigmoid ≈ 0.0009 < 1/255: culled by the reader
            case 1: ply.append(-5.5) // sigmoid ≈ 0.0041: past the cull, under the 0.005 floor
            default: ply.append(rng.unit() * 8 - 2)
            }
            for axis in 0 ..< 3 {
                ply.append(index == 500 && axis == 1 ? -.infinity : rng.unit() * 4 - 6)
            }
            var q = SIMD4<Float>(rng.unit() * 2 - 1, rng.unit() * 2 - 1, rng.unit() * 2 - 1, rng.unit() * 2 - 1)
            if simd_length_squared(q) == 0 { q = SIMD4<Float>(1, 0, 0, 0) }
            ply.append(q.x)
            ply.append(q.y)
            ply.append(q.z)
            ply.append(q.w)
            ply.append(Float(index & 0xFF))
        }
        let url = temporaryDirectory.appendingPathComponent(bigEndian ? "capture-be.ply" : "capture.ply")
        try ply.data.write(to: url)
        return url
    }

    /// A 600-splat degree-1 capture whose properties take every scalar type the reader decodes:
    /// `double` positions and harmonics beside `float` ones, `short` normals, integer rotations
    /// of every width, and `uchar`/`char` properties to skip — so a missed byte swap or a wrong
    /// integer load shows against the legacy decoder.
    private func mixedScalarFixture(bigEndian: Bool) throws -> URL {
        let count = 600
        var rng = SplitMix64(seed: 0x3A1E_D000 + (bigEndian ? 1 : 0))
        var ply = PLYBinaryBuilder(bigEndian: bigEndian, comment: "mixed scalar types")
        ply.property("x", .double)
        ply.property("y", .float)
        ply.property("z", .double)
        ply.property("nx", .short)
        ply.property("tag", .uchar)
        ply.property("f_dc_0", .float)
        ply.property("f_dc_1", .double)
        ply.property("f_dc_2", .float)
        for term in 0 ..< 9 {
            ply.property("f_rest_\(term)", term % 2 == 0 ? .float : .double)
        }
        ply.property("opacity", .float)
        ply.property("flag", .char)
        ply.property("scale_0", .float)
        ply.property("scale_1", .double)
        ply.property("scale_2", .float)
        ply.property("rot_0", .int)
        ply.property("rot_1", .uint)
        ply.property("rot_2", .ushort)
        ply.property("rot_3", .char)
        ply.beginBody(vertexCount: count, trailingFaceElement: false)
        for index in 0 ..< count {
            ply.append(rng.unit() * 4 - 2)
            ply.append(rng.unit() * 2 - 1)
            ply.append(rng.unit() * 4 - 2)
            ply.append(Float(Int(rng.unit() * 2000) - 1000))
            ply.append(Float(index & 0xFF))
            for _ in 0 ..< 3 {
                ply.append(rng.unit() * 2 - 1)
            }
            for _ in 0 ..< 9 {
                ply.append(rng.unit() - 0.5)
            }
            ply.append(index % 41 == 0 ? -7 : rng.unit() * 6 - 1)
            ply.append(Float(Int(rng.unit() * 200) - 100))
            for _ in 0 ..< 3 {
                ply.append(rng.unit() * 3 - 5)
            }
            ply.append(Float(Int(rng.unit() * 7) - 3))
            ply.append(Float(Int(rng.unit() * 5) + 1))
            ply.append(Float(Int(rng.unit() * 9)))
            ply.append(Float(Int(rng.unit() * 7) - 3))
        }
        let url = temporaryDirectory.appendingPathComponent(bigEndian ? "mixed-be.ply" : "mixed-le.ply")
        try ply.data.write(to: url)
        return url
    }

    /// A 300-point cloud without harmonics: `uchar red/green/blue` for the colour, `double`
    /// scales, `short` rotations and a `char` opacity — the plain point-cloud path of the reader.
    private func rgbFixture(bigEndian: Bool) throws -> URL {
        let count = 300
        var rng = SplitMix64(seed: 0x0C01_0000 + (bigEndian ? 1 : 0))
        var ply = PLYBinaryBuilder(bigEndian: bigEndian, comment: "rgb point cloud")
        for name in ["x", "y", "z"] {
            ply.property(name, .float)
        }
        for name in ["red", "green", "blue"] {
            ply.property(name, .uchar)
        }
        ply.property("opacity", .char)
        for name in ["scale_0", "scale_1", "scale_2"] {
            ply.property(name, .double)
        }
        for name in ["rot_0", "rot_1", "rot_2", "rot_3"] {
            ply.property(name, .short)
        }
        ply.beginBody(vertexCount: count, trailingFaceElement: false)
        for _ in 0 ..< count {
            for _ in 0 ..< 3 {
                ply.append(rng.unit() * 2 - 1)
            }
            for _ in 0 ..< 3 {
                ply.append(Float(Int(rng.unit() * 256)))
            }
            ply.append(Float(Int(rng.unit() * 9) - 3))
            for _ in 0 ..< 3 {
                ply.append(rng.unit() * 3 - 5)
            }
            for _ in 0 ..< 4 {
                ply.append(Float(Int(rng.unit() * 7) - 3))
            }
        }
        let url = temporaryDirectory.appendingPathComponent(bigEndian ? "rgb-be.ply" : "rgb-le.ply")
        try ply.data.write(to: url)
        return url
    }

    /// Vertex bytes of `binaryFixture`: 62 `float` properties and a `uchar`.
    private let captureStride = 62 * 4 + 1

    /// Windows of `vertices` vertices for a binary body of `stride`-byte vertices, and of about
    /// `asciiBytes` for an ASCII body.
    private func smallWindows(vertices: Int = 1024, stride: Int = 1, asciiBytes: Int = 2 << 20) -> PLYGaussianSource.Windowing {
        PLYGaussianSource.Windowing(targetWindowBytes: vertices * stride, asciiWindowBytes: asciiBytes, minVerticesPerWindow: 1)
    }

    /// A 1000-splat degree-1 little-endian capture whose dropped vertices sit on either side of
    /// every 64th index — the windows of `smallWindows(vertices: 64)` — and in runs across some:
    /// culled by the reader (a −7 logit), under the cook's opacity floor (−5.5), a NaN centre and
    /// a log scale that overflows `exp` (both degenerate). `nonFiniteColourAt` splats carry a
    /// NaN DC term instead, which no prune catches and the writer must refuse by index.
    /// Returns the file and the indices the cook drops.
    private func boundaryFixture(nonFiniteColourAt: Set<Int> = []) throws -> (url: URL, dropped: Set<Int>) {
        let count = 1000
        var rng = SplitMix64(seed: 0xB0BD_0064)
        var ply = PLYBinaryBuilder(bigEndian: false, comment: "window boundaries")
        for name in ["x", "y", "z", "f_dc_0", "f_dc_1", "f_dc_2"] {
            ply.property(name, .float)
        }
        for term in 0 ..< 9 {
            ply.property("f_rest_\(term)", .float)
        }
        for name in ["opacity", "scale_0", "scale_1", "scale_2", "rot_0", "rot_1", "rot_2", "rot_3"] {
            ply.property(name, .float)
        }
        ply.beginBody(vertexCount: count, trailingFaceElement: false)

        enum Fate { case kept, culled, underFloor, nanCentre, infiniteScale }
        var fates = [Fate](repeating: .kept, count: count)
        for boundary in stride(from: 64, to: count, by: 64) {
            fates[boundary - 1] = .culled
            fates[boundary] = .nanCentre
            fates[boundary + 1] = .underFloor
            if boundary % 128 == 0 {
                // A run of drops across the boundary, culls and prunes interleaved.
                fates[boundary - 3] = .infiniteScale
                fates[boundary - 2] = .culled
                fates[boundary + 2] = .culled
                fates[boundary + 3] = .underFloor
            }
        }
        fates[0] = .culled
        fates[count - 1] = .infiniteScale
        var dropped: Set<Int> = []
        for index in 0 ..< count {
            let fate = fates[index]
            if fate != .kept { dropped.insert(index) }
            ply.append(fate == .nanCentre ? .nan : rng.unit() * 4 - 2)
            ply.append(rng.unit() * 2 - 1)
            ply.append(rng.unit() * 4 - 2)
            for channel in 0 ..< 3 {
                ply.append(nonFiniteColourAt.contains(index) && channel == 1 ? .nan : rng.unit() * 2 - 1)
            }
            for _ in 0 ..< 9 {
                ply.append(rng.unit() - 0.5)
            }
            switch fate {
            case .culled: ply.append(-7)
            case .underFloor: ply.append(-5.5)
            default: ply.append(rng.unit() * 6 - 1)
            }
            for axis in 0 ..< 3 {
                ply.append(fate == .infiniteScale && axis == 2 ? 100 : rng.unit() * 3 - 5)
            }
            for _ in 0 ..< 4 {
                ply.append(rng.unit() * 2 - 1)
            }
        }
        let url = temporaryDirectory.appendingPathComponent("boundaries.ply")
        try ply.data.write(to: url)
        return (url, dropped)
    }

    /// Vertex bytes of `boundaryFixture`: 23 `float` properties.
    private let boundaryStride = 23 * 4

    /// Where the reader cuts an ASCII body into windows of about `windowBytes`: just past the
    /// first newline at or after each estimate, the body's end last. Offsets into the body.
    private func asciiCuts(of ply: URL, windowBytes: Int) throws -> [Int] {
        let data = try Data(contentsOf: ply)
        let bodyOffset = try PLYReader.parseHeader(from: data).1
        let body = [UInt8](data[bodyOffset...])
        var cuts: [Int] = []
        var start = 0
        while start < body.count {
            var cut = min(start + windowBytes, body.count)
            if cut < body.count, let newline = body[cut...].firstIndex(of: 0x0A) {
                cut = newline + 1
            } else if cut < body.count {
                cut = body.count
            }
            cuts.append(cut)
            start = cut
        }
        return cuts
    }

    /// Every binary fixture: the SH3 capture both ways round, the mixed scalar types both ways
    /// round, the RGB point cloud both ways round.
    private func binaryFixtureVariants() throws -> [URL] {
        try [
            binaryFixture(), binaryFixture(bigEndian: true),
            mixedScalarFixture(bigEndian: false), mixedScalarFixture(bigEndian: true),
            rgbFixture(bigEndian: false), rgbFixture(bigEndian: true),
        ]
    }

    /// Options A: the source degree, a non-identity similarity, 16-splat chunks → automatic levels.
    private var transformedOptions: UntoldGSCookOptions {
        var options = UntoldGSCookOptions()
        options.log2ChunkSplats = 4
        options.transform = UntoldGSCookOptions.transform(upAxis: .z, scale: 0.5, yawDegrees: 30, translation: [0.1, 0.2, -0.3])
        options.captureExposureEV = 1.5
        return options
    }

    /// Options B: degree 1, a crop, a budget, 32-splat chunks, no coarse section.
    private var budgetedOptions: UntoldGSCookOptions {
        var options = UntoldGSCookOptions()
        options.log2ChunkSplats = 5
        options.shDegree = 1
        options.cropMin = [-1.8, -1, -1.8]
        options.cropMax = [1.8, 1, 1.8]
        options.maxSplatCount = 700
        options.coarseLevels = .off
        return options
    }

    private func sha256(_ url: URL) throws -> String {
        try SHA256.hash(data: Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
    }

    /// Bakes `ply` through the legacy path and through the streamed one over `windowing` —
    /// production's, or windows the fixture spans `windows` of — and compares everything the
    /// bake returns and every tier's bytes.
    @discardableResult
    private func bakeBothWays(
        ply: URL, name: String, lodFractions: [Float], options: UntoldGSCookOptions,
        windowing: PLYGaussianSource.Windowing = .production, windows: Int? = nil
    ) throws -> BothWays {
        let legacyBase = temporaryDirectory.appendingPathComponent("legacy-\(name).untoldgs")
        let streamedBase = temporaryDirectory.appendingPathComponent("streamed-\(name).untoldgs")
        let legacy = try LegacyGaussianCookPath.bake(
            sourceAsset: LegacyGaussianCookPath.readGaussianAsset(from: ply),
            emptySourceDescription: "source .ply contains no splats",
            outputBaseURL: legacyBase, lodFractions: lodFractions, cookOptions: options
        )
        let source = try PLYGaussianSource(url: ply, windowing: windowing)
        let streamed = try bakeGaussianSplatProgressiveTiers(source: source, outputBaseURL: streamedBase, lodFractions: lodFractions, cookOptions: options, control: nil)
        if let windows {
            XCTAssertEqual(source.windowsRead, windows, "\(name): the body went through \(windows) windows")
        }
        XCTAssertEqual(legacy.cookReport, streamed.cookReport, name)
        XCTAssertEqual(legacy.boundingBoxMin, streamed.boundingBoxMin, name)
        XCTAssertEqual(legacy.boundingBoxMax, streamed.boundingBoxMax, name)
        XCTAssertEqual(legacy.tiers.count, streamed.tiers.count, name)
        for (a, b) in zip(legacy.tiers, streamed.tiers) {
            XCTAssertEqual(a.meanSquaredSplatExtent, b.meanSquaredSplatExtent, name)
            XCTAssertEqual(a.coarseReport, b.coarseReport, name)
            XCTAssertEqual(try Data(contentsOf: a.url), try Data(contentsOf: b.url), "\(name): \(a.url.lastPathComponent) is byte-identical either way")
        }
        return BothWays(tiers: zip(legacy.tiers, streamed.tiers).map { ($0.url, $1.url) }, report: streamed.cookReport)
    }

    /// What `bakeBothWays` compared: each tier's file from either path, and the (equal) report.
    private struct BothWays {
        var tiers: [(legacy: URL, streamed: URL)]
        var report: UntoldGSCookReport
    }

    // MARK: - Byte identity

    func testASCIIFixtureBakesByteIdenticalToTheWholeArrayPath() throws {
        let ply = try asciiFixture()
        var options = UntoldGSCookOptions()
        options.log2ChunkSplats = 7
        options.cropMin = [0, 0, 0]
        options.cropMax = [0.95, 0.95, 0.15]
        options.shDegree = 0
        let single = try bakeBothWays(ply: ply, name: "grid", lodFractions: [1.0], options: options)
        XCTAssertEqual(try sha256(single.tiers[0].streamed), "c27c677da83a97ac272ff3d746f7a5d1e5697e2122ca7d5c53cba28153e583f8")

        options.coarseLevels = .levels(count: 1)
        let twoTier = try bakeBothWays(ply: ply, name: "grid-tiers", lodFractions: [1.0, 0.5], options: options)
        // Every splat of the grid has the same importance: the half tier is decided by the
        // ranking's tie order alone, which has to be the same every run.
        XCTAssertEqual(try sha256(twoTier.tiers[1].streamed), "62485bd1a68fec31cd42c03e64b0c8b4b8eb46867bdd341b017d40e6cdf4c179")
    }

    func testBinarySH3FixtureBakesByteIdenticalToTheWholeArrayPath() throws {
        let ply = try binaryFixture()
        XCTAssertEqual(try PLYReader.readGaussianSplatCount(from: ply), 1100)

        let transformed = try bakeBothWays(ply: ply, name: "capture", lodFractions: [1.0], options: transformedOptions)
        let file = try UntoldGSFile(url: transformed.tiers[0].streamed)
        XCTAssertEqual(file.header.shDegree, 3)
        XCTAssertTrue(file.header.hasCoarseLevels, "69-odd chunks of 16: the automatic section")
        XCTAssertEqual(file.index.coarseRatioLog2, [3, 4])
        XCTAssertEqual(try sha256(transformed.tiers[0].streamed), "e3dc509c394c4428389a6b43dc435489f861d6cb1fc9bbe5948ff21d097776c4")
        try bakeBothWays(ply: ply, name: "capture-tiers", lodFractions: [1.0, 0.5], options: transformedOptions)

        let budgeted = try bakeBothWays(ply: ply, name: "budget", lodFractions: [1.0], options: budgetedOptions)
        let budgetedFile = try UntoldGSFile(url: budgeted.tiers[0].streamed)
        XCTAssertEqual(budgetedFile.header.shDegree, 1)
        XCTAssertEqual(budgetedFile.header.splatCount, 700)
        XCTAssertFalse(budgetedFile.header.hasCoarseLevels)
        XCTAssertEqual(try sha256(budgeted.tiers[0].streamed), "a61d665f6ca56d27897f69e974515d00e50cf1f5d364931446be68129ccdf327")
        try bakeBothWays(ply: ply, name: "budget-tiers", lodFractions: [1.0, 0.5], options: budgetedOptions)
    }

    func testBinaryFixtureReadsIdenticallyThroughBothParsers() throws {
        for ply in try binaryFixtureVariants() {
            let name = ply.lastPathComponent
            let legacy = try LegacyGaussianCookPath.readGaussianAsset(from: ply)
            let streamed = try PLYReader.readGaussianAsset(from: ply)
            XCTAssertEqual(legacy.splats.count, streamed.splats.count, name)
            XCTAssertGreaterThan(streamed.splats.count, 0, name)
            for (a, b) in zip(legacy.splats, streamed.splats) {
                XCTAssertEqual(a.center, b.center, name)
                XCTAssertEqual(a.scale, b.scale, name)
                XCTAssertEqual(a.color, b.color, name)
                XCTAssertEqual(a.quat, b.quat, name)
                XCTAssertEqual(a.opacity, b.opacity, name)
            }
            XCTAssertEqual(legacy.sphericalHarmonics?.degree, streamed.sphericalHarmonics?.degree, name)
            XCTAssertEqual(legacy.sphericalHarmonics?.coefficients, streamed.sphericalHarmonics?.coefficients, name)
        }

        let capture = try PLYReader.readGaussianAsset(from: binaryFixture())
        XCTAssertEqual(capture.splats.count, 1100 - 21, "every 53rd splat is culled by the reader")
        XCTAssertEqual(capture.sphericalHarmonics?.degree, 3)
        let mixedPLY = try mixedScalarFixture(bigEndian: true)
        XCTAssertEqual(try PLYReader.readGaussianSplatCount(from: mixedPLY), 600)
        let mixed = try PLYReader.readGaussianAsset(from: mixedPLY)
        XCTAssertEqual(mixed.sphericalHarmonics?.degree, 1)
        XCTAssertEqual(mixed.splats.count, 600 - 15, "every 41st point is culled")
        let rgbPLY = try rgbFixture(bigEndian: true)
        XCTAssertEqual(try PLYReader.readGaussianSplatCount(from: rgbPLY), 300)
        let rgb = try PLYReader.readGaussianAsset(from: rgbPLY)
        XCTAssertNil(rgb.sphericalHarmonics)
        XCTAssertEqual(rgb.splats.count, 300)
    }

    func testBigEndianCaptureBakesTheSameBytesAsTheLittleEndianOne() throws {
        // The same values in the other byte order: the decoded splats, and so the file, are the
        // same as the little-endian capture's — the SHA pinned above.
        let ply = try binaryFixture(bigEndian: true)
        XCTAssertEqual(try PLYReader.readGaussianSplatCount(from: ply), 1100)
        let output = temporaryDirectory.appendingPathComponent("capture-be.untoldgs")
        _ = try bakeGaussianSplatProgressiveTiers(plyURL: ply, outputBaseURL: output, lodFractions: [1.0], cookOptions: transformedOptions)
        XCTAssertEqual(try sha256(output), "e3dc509c394c4428389a6b43dc435489f861d6cb1fc9bbe5948ff21d097776c4")
    }

    // MARK: - Many windows

    // The fixtures are far below one production window; these run them through windows of a
    // few dozen vertices, so parallel windows landing in source order, the culled and
    // non-finite offsets carried across windows, and an ASCII body's line-boundary cuts and
    // declared-count truncation are all proven against the whole-array path.

    func testBinarySH3FixtureBakesByteIdenticalThroughSixtyFourVertexWindows() throws {
        // 1100 vertices in 64-vertex windows: 17 full and one of 12, read several per batch.
        let windowing = smallWindows(vertices: 64, stride: captureStride)
        for bigEndian in [false, true] {
            let ply = try binaryFixture(bigEndian: bigEndian)
            let name = bigEndian ? "capture-be" : "capture-le"
            XCTAssertEqual(try PLYGaussianSource(url: ply, windowing: windowing).layout.stride, captureStride)

            let transformed = try bakeBothWays(ply: ply, name: "\(name)-w64", lodFractions: [1.0], options: transformedOptions, windowing: windowing, windows: 18)
            XCTAssertEqual(try sha256(transformed.tiers[0].streamed), "e3dc509c394c4428389a6b43dc435489f861d6cb1fc9bbe5948ff21d097776c4", "the same file as through one window")
            try bakeBothWays(ply: ply, name: "\(name)-w64-tiers", lodFractions: [1.0, 0.5], options: transformedOptions, windowing: windowing, windows: 18)

            let budgeted = try bakeBothWays(ply: ply, name: "\(name)-w64-budget", lodFractions: [1.0], options: budgetedOptions, windowing: windowing, windows: 18)
            XCTAssertEqual(try sha256(budgeted.tiers[0].streamed), "a61d665f6ca56d27897f69e974515d00e50cf1f5d364931446be68129ccdf327")
        }
    }

    func testBinaryFixturesReadIdenticallyThroughSmallWindows() throws {
        for ply in try binaryFixtureVariants() {
            let name = ply.lastPathComponent
            let whole = try PLYReader.readGaussianAsset(from: ply)
            let stride = try PLYGaussianSource(url: ply).layout.stride
            let windowed = try PLYReader.readGaussianAsset(from: ply, windowing: smallWindows(vertices: 37, stride: stride))
            XCTAssertEqual(whole.splats.count, windowed.splats.count, name)
            for (a, b) in zip(whole.splats, windowed.splats) {
                XCTAssertEqual(a.center, b.center, name)
                XCTAssertEqual(a.scale, b.scale, name)
                XCTAssertEqual(a.color, b.color, name)
                XCTAssertEqual(a.quat, b.quat, name)
                XCTAssertEqual(a.opacity, b.opacity, name)
            }
            XCTAssertEqual(whole.sphericalHarmonics?.coefficients, windowed.sphericalHarmonics?.coefficients, name)
        }
    }

    func testASCIIFixtureBakesByteIdenticalThroughTwoKilobyteWindows() throws {
        let ply = try asciiFixture()
        let cuts = try asciiCuts(of: ply, windowBytes: 2048)
        XCTAssertGreaterThan(cuts.count, 8, "the 300-line grid spans many 2 KB windows")
        let windowing = smallWindows(asciiBytes: 2048)

        var options = UntoldGSCookOptions()
        options.log2ChunkSplats = 7
        options.cropMin = [0, 0, 0]
        options.cropMax = [0.95, 0.95, 0.15]
        options.shDegree = 0
        let single = try bakeBothWays(ply: ply, name: "grid-w2k", lodFractions: [1.0], options: options, windowing: windowing, windows: cuts.count)
        XCTAssertEqual(try sha256(single.tiers[0].streamed), "c27c677da83a97ac272ff3d746f7a5d1e5697e2122ca7d5c53cba28153e583f8", "the same file as through one window")

        options.coarseLevels = .levels(count: 1)
        let twoTier = try bakeBothWays(ply: ply, name: "grid-w2k-tiers", lodFractions: [1.0, 0.5], options: options, windowing: windowing, windows: cuts.count)
        XCTAssertEqual(try sha256(twoTier.tiers[1].streamed), "62485bd1a68fec31cd42c03e64b0c8b4b8eb46867bdd341b017d40e6cdf4c179")
    }

    func testASCIIBodyLongerThanItsDeclaredCountIsCutToTheCountAcrossWindows() throws {
        // 300 lines under a header declaring 250, the first excess line and a later one
        // unreadable as vertices: the whole-array path took the first 250 lines and never looked
        // at the rest. The declared count has to run out inside a window, with the excess
        // spilling over the windows after it — where its lines, readable or not, are counted
        // but never parsed.
        let ply = try asciiFixture(lineCount: 300, declaredCount: 250, unreadableLines: [250, 291])
        let cuts = try asciiCuts(of: ply, windowBytes: 2048)
        let data = try Data(contentsOf: ply)
        let bodyOffset = try PLYReader.parseHeader(from: data).1
        let body = [UInt8](data[bodyOffset...])
        var endOfDeclared = 0
        for _ in 0 ..< 250 {
            endOfDeclared = try XCTUnwrap(body[endOfDeclared...].firstIndex(of: 0x0A)) + 1
        }
        XCTAssertFalse(cuts.contains(endOfDeclared), "the count runs out inside a window")
        XCTAssertGreaterThan(cuts.filter { $0 > endOfDeclared }.count, 1, "the excess spans a window boundary")

        let legacy = try LegacyGaussianCookPath.readGaussianAsset(from: ply)
        XCTAssertEqual(legacy.splats.count, 250)
        let windowed = try PLYReader.readGaussianAsset(from: ply, windowing: smallWindows(asciiBytes: 2048))
        XCTAssertEqual(windowed.splats.count, 250)
        XCTAssertEqual(legacy.sphericalHarmonics?.coefficients, windowed.sphericalHarmonics?.coefficients)
        for (a, b) in zip(legacy.splats, windowed.splats) {
            XCTAssertEqual(a.center, b.center)
            XCTAssertEqual(a.color, b.color)
        }

        var options = UntoldGSCookOptions()
        options.log2ChunkSplats = 5
        options.shDegree = 1
        let twoTier = try bakeBothWays(ply: ply, name: "grid-250", lodFractions: [1.0, 0.5], options: options, windowing: smallWindows(asciiBytes: 2048), windows: cuts.count)
        XCTAssertEqual(twoTier.report.inputSplatCount, 250)
        XCTAssertEqual(try Int(UntoldGSFile(url: twoTier.tiers[0].streamed).header.splatCount), 250)

        // An unreadable line within the count is still an error, wherever the windows fall.
        let broken = try asciiFixture(lineCount: 300, declaredCount: 250, unreadableLines: [249])
        XCTAssertThrowsError(try PLYReader.readGaussianAsset(from: broken, windowing: smallWindows(asciiBytes: 2048))) { error in
            guard case let PLYError.invalidData(message)? = error as? PLYError else {
                return XCTFail("\(error)")
            }
            XCTAssertTrue(message.hasPrefix("Cannot parse float"), message)
        }
    }

    func testCulledAndDegenerateVerticesOnWindowBoundariesBakeByteIdentical() throws {
        // 15 boundaries, every other one (7) with the longer run; 1000 vertices in 16 windows.
        let (ply, dropped) = try boundaryFixture()
        XCTAssertEqual(dropped.count, 75)
        let windowing = smallWindows(vertices: 64, stride: boundaryStride)
        XCTAssertEqual(try PLYGaussianSource(url: ply, windowing: windowing).layout.stride, boundaryStride)
        let culled = 15 + 2 * 7 + 1
        let read = try PLYReader.readGaussianAsset(from: ply, windowing: windowing)
        XCTAssertEqual(read.splats.count, 1000 - culled, "culled before every boundary, on both sides of every other, and the first")
        XCTAssertEqual(read.sphericalHarmonics?.coefficients, try LegacyGaussianCookPath.readGaussianAsset(from: ply).sphericalHarmonics?.coefficients)

        var options = transformedOptions
        options.log2ChunkSplats = 5
        let single = try bakeBothWays(ply: ply, name: "boundaries", lodFractions: [1.0], options: options, windowing: windowing, windows: 16)
        let report = single.report
        XCTAssertEqual(report.inputSplatCount, 1000 - culled)
        XCTAssertEqual(report.prunedByOpacity, 15 + 7, "under the floor after every boundary, and after every other")
        XCTAssertEqual(report.prunedByDegenerateGeometry, 15 + 7 + 1, "a NaN centre on every boundary, an overflowed scale before every other, and the last")
        XCTAssertEqual(report.prunedByCrop, 0)
        XCTAssertEqual(report.keptSplatCount, 1000 - dropped.count)
        XCTAssertEqual(try Int(UntoldGSFile(url: single.tiers[0].streamed).header.splatCount), 1000 - dropped.count)
        try bakeBothWays(ply: ply, name: "boundaries-tiers", lodFractions: [1.0, 0.5], options: options, windowing: windowing, windows: 16)
    }

    func testNonFiniteSplatsPastWindowBoundariesAreRefusedByTheirStoreIndex() throws {
        // A NaN colour survives every prune and reaches the writer, which refuses it by its
        // index in the cooked store: the first one's index, five windows and their drops in,
        // has to be the same from the windowed cook as from the whole array.
        let (ply, dropped) = try boundaryFixture(nonFiniteColourAt: [325, 700])
        XCTAssertFalse(dropped.contains(325))
        let expectedIndex = 325 - dropped.filter { $0 < 325 }.count
        XCTAssertGreaterThan(325 - expectedIndex, 20, "the drops before it shift its index")
        let expected = UntoldGSError.invalidInput("splat \(expectedIndex) has non-finite data or a non-positive scale")

        var options = transformedOptions
        options.log2ChunkSplats = 5
        XCTAssertThrowsError(
            try LegacyGaussianCookPath.bake(
                sourceAsset: LegacyGaussianCookPath.readGaussianAsset(from: ply), emptySourceDescription: "",
                outputBaseURL: temporaryDirectory.appendingPathComponent("legacy-nan.untoldgs"), lodFractions: [1.0], cookOptions: options
            )
        ) { error in
            XCTAssertEqual(error as? UntoldGSError, expected)
        }
        let source = try PLYGaussianSource(url: ply, windowing: smallWindows(vertices: 64, stride: boundaryStride))
        XCTAssertThrowsError(
            try bakeGaussianSplatProgressiveTiers(
                source: source, outputBaseURL: temporaryDirectory.appendingPathComponent("streamed-nan.untoldgs"), lodFractions: [1.0], cookOptions: options, control: nil
            )
        ) { error in
            XCTAssertEqual(error as? UntoldGSError, expected)
        }
        XCTAssertEqual(source.windowsRead, 16)
    }

    func testReadProgressClimbsThroughEveryBatchOfWindows() throws {
        // Four-vertex windows: 275 of them, batched a core's worth at a time, so the read phase
        // reports many times — from 0, strictly up through (0, 1), to exactly 1.
        let ply = try binaryFixture()
        let reports = ProgressLog()
        let source = try PLYGaussianSource(url: ply, windowing: smallWindows(vertices: 4, stride: captureStride))
        _ = try bakeGaussianSplatProgressiveTiers(
            source: source, outputBaseURL: temporaryDirectory.appendingPathComponent("progress-w4.untoldgs"),
            lodFractions: [1.0], cookOptions: transformedOptions, control: UntoldGSCookControl(progress: { reports.append($0) })
        )
        XCTAssertEqual(source.windowsRead, 275)
        let read = reports.all.filter { $0.phase == .read }.map(\.fraction)
        XCTAssertEqual(read.first, 0)
        XCTAssertEqual(read.last, 1)
        XCTAssertGreaterThanOrEqual(read.count, 4, "at least two batches between the first and the last report")
        for (previous, next) in zip(read, read.dropFirst()) {
            XCTAssertGreaterThan(next, previous, "read fractions strictly increase")
        }
        for fraction in read.dropFirst().dropLast() {
            XCTAssertTrue(fraction > 0 && fraction < 1, "\(fraction) is within (0, 1)")
        }
    }

    // MARK: - Centre bounds

    func testStreamedCenterBoundsMatchTheLoadedSplats() throws {
        for ply in try [asciiFixture()] + binaryFixtureVariants() {
            let splats = try PLYReader.readGaussianSplats(from: ply)
            var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
            var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
            for splat in splats {
                minimum = simd_min(minimum, SIMD3<Float>(splat.center.x, splat.center.y, splat.center.z))
                maximum = simd_max(maximum, SIMD3<Float>(splat.center.x, splat.center.y, splat.center.z))
            }
            let bounds = try XCTUnwrap(PLYReader.readGaussianCenterBounds(from: ply))
            XCTAssertEqual(bounds.min, minimum, ply.lastPathComponent)
            XCTAssertEqual(bounds.max, maximum, ply.lastPathComponent)
        }
    }

    // MARK: - Progress and cancellation

    func testProgressRunsThroughThePhasesInOrderAndEndsAtOne() throws {
        let ply = try binaryFixture()
        let reports = ProgressLog()
        let control = UntoldGSCookControl(progress: { reports.append($0) })
        let output = temporaryDirectory.appendingPathComponent("progress.untoldgs")
        _ = try bakeGaussianSplatProgressiveTiers(plyURL: ply, outputBaseURL: output, lodFractions: [1.0, 0.5], cookOptions: transformedOptions, control: control)

        let all = reports.all
        XCTAssertFalse(all.isEmpty)
        XCTAssertEqual(all.first?.phase, .read)
        XCTAssertEqual(all.last?.phase, .write)
        XCTAssertEqual(all.last?.overall, 1)
        XCTAssertEqual(all.last?.tierIndex, 1)
        XCTAssertTrue(all.allSatisfy { $0.tierCount == 2 })
        let order: [UntoldGSCookPhase] = [.read, .cook, .chunk, .coarsen, .write]
        var previous = all[0]
        for report in all.dropFirst() {
            XCTAssertGreaterThanOrEqual(report.overall, previous.overall, "overall never goes back")
            XCTAssertTrue(report.fraction >= 0 && report.fraction <= 1)
            if report.tierIndex == previous.tierIndex {
                let a = try XCTUnwrap(order.firstIndex(of: previous.phase))
                let b = try XCTUnwrap(order.firstIndex(of: report.phase))
                XCTAssertGreaterThanOrEqual(b, a, "phases arrive in order within a tier")
                if a == b {
                    XCTAssertGreaterThanOrEqual(report.fraction, previous.fraction, "fractions are monotonic within a phase")
                }
            } else {
                XCTAssertEqual(report.tierIndex, previous.tierIndex + 1)
            }
            if report.phase != previous.phase || report.tierIndex != previous.tierIndex, previous.fraction == 1, report.fraction == 0 {
                // A phase that ended at 1 hands over to one starting at 0 at the same overall —
                // also from `chunk` to `write` in the second tier, which is below the automatic
                // coarse-level threshold and never reports `coarsen`.
                XCTAssertEqual(report.overall, previous.overall, accuracy: 1e-5, "\(previous.phase) → \(report.phase) is continuous")
            }
            previous = report
        }
        for phase in order {
            XCTAssertTrue(all.contains { $0.phase == phase }, "\(phase) is reported")
        }
        XCTAssertTrue(all.contains { $0.tierIndex == 1 && $0.phase == .chunk }, "the second tier reports chunk")
        XCTAssertFalse(all.contains { $0.tierIndex == 1 && $0.phase == .coarsen }, "the second tier has no coarse levels")
    }

    func testProgressStaysMonotonicWhenTheTierHasNoCoarseLevels() throws {
        // Without coarse levels the chunk loop reports as `chunk` after the ordering did; 135
        // chunks of 8 take several batches, so the fraction must carry on from the ordering's
        // share rather than start again at zero.
        let ply = try binaryFixture()
        var options = transformedOptions
        options.log2ChunkSplats = 3
        options.coarseLevels = .off
        let reports = ProgressLog()
        let output = temporaryDirectory.appendingPathComponent("flat.untoldgs")
        _ = try bakeGaussianSplatProgressiveTiers(plyURL: ply, outputBaseURL: output, lodFractions: [1.0], cookOptions: options, control: UntoldGSCookControl(progress: { reports.append($0) }))

        let chunk = reports.all.filter { $0.phase == .chunk }
        XCTAssertGreaterThan(chunk.count, 4, "the ordering and every chunk batch report")
        XCTAssertFalse(reports.all.contains { $0.phase == .coarsen })
        for (previous, next) in zip(chunk, chunk.dropFirst()) {
            XCTAssertGreaterThanOrEqual(next.fraction, previous.fraction, "chunk fractions never run backwards")
            XCTAssertGreaterThanOrEqual(next.overall, previous.overall)
        }
        XCTAssertEqual(chunk.last?.fraction, 1)
        XCTAssertEqual(reports.all.last?.overall, 1)

        // The chunk loop takes the coarsening's share of the tier: `chunk` spans 0.40…0.90 of
        // the whole and `write` carries on from where it ended, rather than leaping from 0.50.
        XCTAssertEqual(try XCTUnwrap(chunk.first?.overall), 0.40, accuracy: 1e-5)
        XCTAssertEqual(try XCTUnwrap(chunk.last?.overall), 0.90, accuracy: 1e-5)
        let write = reports.all.filter { $0.phase == .write }
        XCTAssertEqual(try XCTUnwrap(write.first?.overall), try XCTUnwrap(chunk.last?.overall), accuracy: 1e-5, "write starts where chunk ended")
    }

    func testCancellationInEveryPhaseLeavesNoFileBehind() throws {
        let ply = try binaryFixture()
        for phase in UntoldGSCookPhase.allCases {
            let directory = temporaryDirectory.appendingPathComponent("cancel-\(phase.rawValue)", isDirectory: true)
            let output = directory.appendingPathComponent("cancelled.untoldgs")
            let seen = ProgressLog()
            let control = UntoldGSCookControl(
                progress: { report in
                    // Cancel the moment the second tier reaches `phase`, so the first tier —
                    // complete in its temporary by then — has to go too. `read` and `cook` run once;
                    // the half tier is below the automatic coarse-level threshold, so
                    // `coarsen` is cancelled in the first tier, with its temporary file open.
                    if report.phase == phase, report.tierIndex == 1 || phase == .read || phase == .cook || phase == .coarsen {
                        seen.cancel()
                    }
                    seen.append(report)
                },
                isCancelled: { seen.isCancelled }
            )
            XCTAssertThrowsError(
                try bakeGaussianSplatProgressiveTiers(plyURL: ply, outputBaseURL: output, lodFractions: [1.0, 0.5], cookOptions: transformedOptions, control: control),
                "\(phase)"
            ) { error in
                XCTAssertEqual(error as? UntoldGSCookError, .cancelled, "\(phase)")
            }
            XCTAssertTrue(seen.isCancelled, "\(phase) was reached")
            let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
            XCTAssertEqual(leftovers, [], "\(phase): no tier and no temporary file remains")
        }
    }

    func testCancelledRecookLeavesThePreviousTiersIntact() throws {
        // A directory already holding a bake's tiers: a re-cook cancelled in its second tier
        // must leave every one of them as it was — no tier of the new bake in place of an old
        // one, no mixed set observable while it runs — and a re-cook left to finish replaces
        // the whole set.
        let ply = try binaryFixture()
        let directory = temporaryDirectory.appendingPathComponent("recook", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let output = directory.appendingPathComponent("scene.untoldgs")
        let previous = ["scene_lod0.untoldgs": "OLD-LOD0", "scene_lod1.untoldgs": "OLD-LOD1"]
        for (name, marker) in previous {
            try Data(marker.utf8).write(to: directory.appendingPathComponent(name))
        }
        func contents() throws -> [String: String] {
            var found: [String: String] = [:]
            for name in try FileManager.default.contentsOfDirectory(atPath: directory.path) where name != ply.lastPathComponent {
                let data = try Data(contentsOf: directory.appendingPathComponent(name))
                found[name] = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
            }
            return found
        }

        let seen = ProgressLog()
        let firstTier = directory.appendingPathComponent("scene_lod0.untoldgs")
        let control = UntoldGSCookControl(
            progress: { report in
                if report.tierIndex == 1 {
                    // The first tier is complete while the second bakes: it must not have
                    // replaced the previous bake's yet.
                    if (try? String(contentsOf: firstTier, encoding: .utf8)) != "OLD-LOD0" {
                        seen.noteMixedSet()
                    }
                    if report.phase == .chunk {
                        seen.cancel()
                    }
                }
                seen.append(report)
            },
            isCancelled: { seen.isCancelled }
        )
        XCTAssertThrowsError(
            try bakeGaussianSplatProgressiveTiers(plyURL: ply, outputBaseURL: output, lodFractions: [1.0, 0.5], cookOptions: transformedOptions, control: control)
        ) { error in
            XCTAssertEqual(error as? UntoldGSCookError, .cancelled)
        }
        XCTAssertTrue(seen.isCancelled, "the second tier was reached")
        XCTAssertFalse(seen.sawMixedSet, "the new first tier never stood beside the old second one")
        XCTAssertEqual(try contents(), previous, "the previous tiers, untouched, and no temporary")

        let result = try bakeGaussianSplatProgressiveTiers(plyURL: ply, outputBaseURL: output, lodFractions: [1.0, 0.5], cookOptions: transformedOptions)
        XCTAssertEqual(result.tiers.map(\.url.lastPathComponent), ["scene_lod0.untoldgs", "scene_lod1.untoldgs"])
        XCTAssertEqual(try contents().keys.sorted(), ["scene_lod0.untoldgs", "scene_lod1.untoldgs"])
        for tier in result.tiers {
            XCTAssertNoThrow(try UntoldGSFile(url: tier.url), "\(tier.url.lastPathComponent) is the new bake's")
        }
    }

    func testRankingPollsAsItRunsWithoutChangingItsResult() throws {
        var rng = SplitMix64(seed: 0xBA5E)
        let centers = (0 ..< 5000).map { _ in simd_float3(rng.unit() * 4 - 2, rng.unit(), rng.unit() * 4 - 2) }
        let importances = (0 ..< 5000).map { _ in rng.unit() }
        let plain = try spatiallyInterleavedGaussianRanking(count: centers.count, center: { centers[$0] }, importance: { importances[$0] })
        var fractions: [Double] = []
        let polled = try spatiallyInterleavedGaussianRanking(
            count: centers.count, center: { centers[$0] }, importance: { importances[$0] },
            poll: { fractions.append($0) }
        )
        XCTAssertEqual(polled, plain, "the poll never changes the ranking")
        XCTAssertEqual(Set(plain).count, centers.count)
        XCTAssertGreaterThan(fractions.count, 5, "every pass of the ranking reports")
        XCTAssertEqual(fractions.last, 1)
        for (previous, next) in zip(fractions, fractions.dropFirst()) {
            XCTAssertGreaterThanOrEqual(next, previous, "the ranking's progress never runs backwards")
        }

        struct Stop: Error {}
        XCTAssertThrowsError(
            try spatiallyInterleavedGaussianRanking(
                count: centers.count, center: { centers[$0] }, importance: { importances[$0] },
                poll: { if $0 >= 0.5 { throw Stop() } }
            )
        ) { error in
            XCTAssertTrue(error is Stop)
        }
    }

    func testCancellationDuringTheRankingStopsBeforeTheFirstTier() throws {
        // A multi-tier bake ranks the whole store between the cook's bounds and the first
        // tier: cancelling in the ranking — a `cook` report past its first half — must land
        // there, before any tier is ordered, and leave nothing behind.
        let ply = try binaryFixture()
        let directory = temporaryDirectory.appendingPathComponent("cancel-ranking", isDirectory: true)
        let output = directory.appendingPathComponent("cancelled.untoldgs")
        let seen = ProgressLog()
        let control = UntoldGSCookControl(
            progress: { report in
                if report.phase == .cook, report.fraction > 0.5, report.fraction < 1 {
                    seen.cancel()
                }
                seen.append(report)
            },
            isCancelled: { seen.isCancelled }
        )
        XCTAssertThrowsError(
            try bakeGaussianSplatProgressiveTiers(plyURL: ply, outputBaseURL: output, lodFractions: [1.0, 0.5, 0.25], cookOptions: transformedOptions, control: control)
        ) { error in
            XCTAssertEqual(error as? UntoldGSCookError, .cancelled)
        }
        XCTAssertTrue(seen.isCancelled, "the ranking reported")
        XCTAssertFalse(seen.all.contains { $0.phase == .chunk }, "no tier was started")
        XCTAssertEqual((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [], [])
    }

    func testTaskCancellationStopsTheCook() async throws {
        let ply = try binaryFixture()
        let output = temporaryDirectory.appendingPathComponent("task-cancelled.untoldgs")
        let options = transformedOptions
        let task = Task.detached {
            try bakeGaussianSplatProgressiveTiers(plyURL: ply, outputBaseURL: output, lodFractions: [1.0], cookOptions: options, control: UntoldGSCookControl())
        }
        task.cancel()
        do {
            _ = try await task.value
            // A very fast cook may finish before the cancellation lands; then the file exists.
            XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        } catch {
            XCTAssertEqual(error as? UntoldGSCookError, .cancelled)
            XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
        }
    }

    func testCancellationErrorDescribesItself() {
        XCTAssertEqual(UntoldGSCookError.cancelled.description, "the cook was cancelled")
    }
}

/// Progress reports collected from the cooking thread.
private final class ProgressLog: @unchecked Sendable {
    private let lock = NSLock()
    private var reports: [UntoldGSCookProgress] = []
    private var cancelled = false

    func append(_ report: UntoldGSCookProgress) {
        lock.withLock { reports.append(report) }
    }

    var all: [UntoldGSCookProgress] {
        lock.withLock { reports }
    }

    func cancel() {
        lock.withLock { cancelled = true }
    }

    var isCancelled: Bool {
        lock.withLock { cancelled }
    }

    private var mixedSet = false

    func noteMixedSet() {
        lock.withLock { mixedSet = true }
    }

    var sawMixedSet: Bool {
        lock.withLock { mixedSet }
    }
}

/// Writes a binary PLY: the header from the properties declared, then each vertex's values
/// encoded in the property's scalar type and the file's byte order.
private struct PLYBinaryBuilder {
    enum Scalar: String {
        case float, double, uchar, char, ushort, short, uint, int
    }

    let bigEndian: Bool
    private var header: [String]
    private var types: [Scalar] = []
    private var slot = 0
    private(set) var data = Data()

    init(bigEndian: Bool, comment: String) {
        self.bigEndian = bigEndian
        header = ["ply", "format \(bigEndian ? "binary_big_endian" : "binary_little_endian") 1.0", "comment \(comment)"]
    }

    mutating func property(_ name: String, _ type: Scalar) {
        header.append("property \(type.rawValue) \(name)")
        types.append(type)
    }

    mutating func beginBody(vertexCount: Int, trailingFaceElement: Bool) {
        var lines = Array(header.prefix(3)) + ["element vertex \(vertexCount)"] + header.dropFirst(3)
        if trailingFaceElement {
            lines += ["element face 0", "property list uchar int vertex_indices"]
        }
        lines.append("end_header")
        data = Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    /// The next property's value of the vertex, encoded in its declared type.
    mutating func append(_ value: Float) {
        let type = types[slot % types.count]
        slot += 1
        switch type {
        case .float: appendBits(value.bitPattern)
        case .double: appendBits(Double(value).bitPattern)
        case .uchar: data.append(UInt8(value))
        case .char: data.append(UInt8(bitPattern: Int8(value)))
        case .ushort: appendBits(UInt16(value))
        case .short: appendBits(UInt16(bitPattern: Int16(value)))
        case .uint: appendBits(UInt32(value))
        case .int: appendBits(UInt32(bitPattern: Int32(value)))
        }
    }

    private mutating func appendBits(_ bits: some FixedWidthInteger) {
        var ordered = bigEndian ? bits.bigEndian : bits.littleEndian
        withUnsafeBytes(of: &ordered) { data.append(contentsOf: $0) }
    }
}

private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Float {
        Float(next() >> 40) / Float(1 << 24)
    }
}
