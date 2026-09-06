//
//  UntoldGSCookerTests.swift
//  UntoldEngineTests
//
//  Tests for the splat cooker behind `untoldengine export --splat-*`: pruning,
//  crop, baked registration transform, SH degree selection, and a bake roundtrip.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import simd
@testable import UntoldEngine
import XCTest

final class UntoldGSCookerTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDown() {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        super.tearDown()
    }

    // MARK: - Pruning and crop

    func testPruningByOpacityGeometryAndCrop() throws {
        var splats = (0 ..< 20).map { index in makeSplat(center: [Float(index), 0, 0]) }
        splats[0].opacity = 0.001
        splats[1].scale = [0, 0.01, 0.01, 1]
        splats[2].center.y = .nan
        var options = UntoldGSCookOptions()
        options.cropMin = [4.5, -1, -1]
        options.cropMax = [14.5, 1, 1]
        options.cropMargin = 0.4 // admits 4.1...14.9 → indices 5...14

        let cooked = try UntoldGSCooker.cook(asset: GaussianSplatAsset(splats: splats, sphericalHarmonics: nil), options: options)
        XCTAssertEqual(cooked.report.inputSplatCount, 20)
        XCTAssertEqual(cooked.report.prunedByOpacity, 1)
        XCTAssertEqual(cooked.report.prunedByDegenerateGeometry, 2)
        XCTAssertEqual(cooked.report.prunedByCrop, 7) // 3, 4, 15...19
        XCTAssertEqual(cooked.report.keptSplatCount, 10)
        XCTAssertEqual(cooked.report.shDegree, 0)
        XCTAssertEqual(cooked.asset.splats.map(\.center.x), (5 ... 14).map { Float($0) })
        XCTAssertNil(cooked.asset.sphericalHarmonics)
    }

    func testSplatBudgetKeepsTheMostImportantInSourceOrder() throws {
        // importance = opacity × geometric mean scale: 0.9·0.01, 0.5·0.02, 0.2·0.01, 0.9·0.005, 0.1·0.1, 0.9·0.01
        let splats: [GaussianSplat] = [
            GaussianSplat(center: [0, 0, 0, 1], scale: [0.01, 0.01, 0.01, 1], color: [1, 1, 1, 1], quat: [1, 0, 0, 0], opacity: 0.9), // 0.009
            GaussianSplat(center: [1, 0, 0, 1], scale: [0.02, 0.02, 0.02, 1], color: [1, 1, 1, 1], quat: [1, 0, 0, 0], opacity: 0.5), // 0.010
            GaussianSplat(center: [2, 0, 0, 1], scale: [0.01, 0.01, 0.01, 1], color: [1, 1, 1, 1], quat: [1, 0, 0, 0], opacity: 0.2), // 0.002
            GaussianSplat(center: [3, 0, 0, 1], scale: [0.005, 0.005, 0.005, 1], color: [1, 1, 1, 1], quat: [1, 0, 0, 0], opacity: 0.9), // 0.0045
            GaussianSplat(center: [4, 0, 0, 1], scale: [0.1, 0.1, 0.1, 1], color: [1, 1, 1, 1], quat: [1, 0, 0, 0], opacity: 0.1), // 0.010
            GaussianSplat(center: [5, 0, 0, 1], scale: [0.01, 0.01, 0.01, 1], color: [1, 1, 1, 1], quat: [1, 0, 0, 0], opacity: 0.9), // 0.009
        ]
        var options = UntoldGSCookOptions()
        options.maxSplatCount = 3
        let cooked = try UntoldGSCooker.cook(asset: GaussianSplatAsset(splats: splats, sphericalHarmonics: nil), options: options)

        // The two 0.010 splats and the first 0.009 (ties at the cut-off keep the earlier splat).
        XCTAssertEqual(cooked.asset.splats.map(\.center.x), [0, 1, 4])
        XCTAssertEqual(cooked.report.keptSplatCount, 3)
        XCTAssertEqual(cooked.report.prunedByBudget, 3)
        XCTAssertEqual(cooked.report.inputSplatCount, 6)

        // A budget at or above the survivors changes nothing.
        options.maxSplatCount = 6
        let untouched = try UntoldGSCooker.cook(asset: GaussianSplatAsset(splats: splats, sphericalHarmonics: nil), options: options)
        XCTAssertEqual(untouched.report.prunedByBudget, 0)
        XCTAssertEqual(untouched.asset.splats.count, 6)

        // The budget applies after the other pruning steps and keeps the SH rows aligned.
        options.maxSplatCount = 2
        options.minimumOpacity = 0.3 // drops centres 2 and 4 first
        // Degree 1: DC plus three coefficients per channel, twelve floats per splat.
        let harmonics = GaussianSphericalHarmonics(degree: 1, coefficientsPerChannel: 4, coefficients: (0 ..< 6 * 12).map { Float($0) })
        let pruned = try UntoldGSCooker.cook(asset: GaussianSplatAsset(splats: splats, sphericalHarmonics: harmonics), options: options)
        XCTAssertEqual(pruned.report.prunedByOpacity, 2)
        XCTAssertEqual(pruned.report.prunedByBudget, 2)
        XCTAssertEqual(pruned.asset.splats.map(\.center.x), [0, 1])
        XCTAssertEqual(pruned.asset.sphericalHarmonics?.coefficients.count, 24, "two survivors keep their twelve coefficients each")
        XCTAssertEqual(pruned.asset.sphericalHarmonics?.coefficients.prefix(12).map { $0 }, (0 ..< 12).map { Float($0) }, "the first survivor keeps its own SH row")
    }

    func testSplatBudgetPresetsMatchTheRuntimeLimits() {
        XCTAssertEqual(UntoldGSCookOptions.splatBudgetMobile, 5_242_880)
        XCTAssertEqual(UntoldGSCookOptions.splatBudgetMac, 16_777_216)
        #if os(macOS)
            XCTAssertEqual(GaussianRuntimeLimits.maxSplatsPerEntity, GaussianRuntimeLimits.maxSplatsPerEntityMac)
        #else
            XCTAssertEqual(GaussianRuntimeLimits.maxSplatsPerEntity, GaussianRuntimeLimits.maxSplatsPerEntityMobile)
        #endif
    }

    func testCookFailsWhenNothingSurvives() {
        var splat = makeSplat(center: .zero)
        splat.opacity = 0
        XCTAssertThrowsError(try UntoldGSCooker.cook(asset: GaussianSplatAsset(splats: [splat], sphericalHarmonics: nil))) { error in
            guard case let .noSplatsLeftAfterPruning(report)? = error as? UntoldGSCookError else {
                return XCTFail("unexpected error \(error)")
            }
            XCTAssertEqual(report.prunedByOpacity, 1)
        }
    }

    func testDefaultOptionsPassEverythingThrough() throws {
        let splats = (0 ..< 5).map { index in makeSplat(center: [Float(index), 1, 2]) }
        let cooked = try UntoldGSCooker.cook(asset: GaussianSplatAsset(splats: splats, sphericalHarmonics: nil))
        XCTAssertEqual(cooked.report, .passthrough(splatCount: 5, shDegree: 0))
        XCTAssertEqual(cooked.asset.splats.map(\.center), splats.map(\.center))
    }

    // MARK: - Spherical harmonics

    func testSHDegreeReductionKeepsDCAndLowOrdersPerChannel() throws {
        // Degree 2: 9 per channel including DC.
        var coefficients: [Float] = []
        for channel in 0 ..< 3 {
            for term in 0 ..< 9 {
                coefficients.append(Float(channel * 100 + term))
            }
        }
        let asset = GaussianSplatAsset(
            splats: [makeSplat(center: .zero)],
            sphericalHarmonics: GaussianSphericalHarmonics(degree: 2, coefficientsPerChannel: 9, coefficients: coefficients)
        )
        var options = UntoldGSCookOptions()
        options.shDegree = 1
        let cooked = try UntoldGSCooker.cook(asset: asset, options: options)
        XCTAssertEqual(cooked.report.shDegree, 1)
        XCTAssertEqual(cooked.asset.sphericalHarmonics?.degree, 1)
        XCTAssertEqual(cooked.asset.sphericalHarmonics?.coefficientsPerChannel, 4)
        XCTAssertEqual(cooked.asset.sphericalHarmonics?.coefficients, [0, 1, 2, 3, 100, 101, 102, 103, 200, 201, 202, 203])

        options.shDegree = 0
        XCTAssertNil(try UntoldGSCooker.cook(asset: asset, options: options).asset.sphericalHarmonics)

        options.shDegree = 3
        XCTAssertThrowsError(try UntoldGSCooker.cook(asset: asset, options: options)) { error in
            XCTAssertEqual(error as? UntoldGSCookError, .requestedSHDegreeExceedsSource(requested: 3, source: 2))
        }
    }

    // MARK: - Transform

    func testSimilarityTransformIsBakedIntoImporterSplats() throws {
        let yaw = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
        var transform = simd_mul(simd_float4x4(yaw), simd_float4x4(diagonal: [2, 2, 2, 1]))
        transform.columns.3 = [10, 0, 0, 1]

        var splat = makeSplat(center: [1, 0, 0])
        splat.scale = [0.1, 0.2, 0.3, 1]
        var options = UntoldGSCookOptions()
        options.transform = transform
        let cooked = try UntoldGSCooker.cook(asset: GaussianSplatAsset(splats: [splat], sphericalHarmonics: nil), options: options)
        let result = cooked.asset.splats[0]

        // (1,0,0) scaled by 2 → (2,0,0), yawed 90° about Y → (0,0,-2), translated → (10,0,-2).
        XCTAssertEqual(result.center.x, 10, accuracy: 1e-5)
        XCTAssertEqual(result.center.y, 0, accuracy: 1e-5)
        XCTAssertEqual(result.center.z, -2, accuracy: 1e-5)
        XCTAssertEqual(result.scale.x, 0.2, accuracy: 1e-6)
        XCTAssertEqual(result.scale.z, 0.6, accuracy: 1e-6)
        // PLY order (w, x, y, z): the identity rotation becomes the yaw.
        let q = simd_quatf(ix: result.quat.y, iy: result.quat.z, iz: result.quat.w, r: result.quat.x)
        XCTAssertEqual(q.act(SIMD3<Float>(1, 0, 0)).z, -1, accuracy: 1e-5)

        let write = UntoldGSCooker.writeOptions(for: options)
        XCTAssertEqual(write.splatToMesh, transform)
    }

    func testUpAxisRotationsBringCapturesToYUp() {
        let up = SIMD3<Float>(0, 1, 0)
        func rotate(_ axis: UntoldGSCaptureUpAxis, _ v: SIMD3<Float>) -> SIMD3<Float> {
            let r = axis.rotation * SIMD4<Float>(v, 1)
            return SIMD3<Float>(r.x, r.y, r.z)
        }
        XCTAssertEqual(rotate(.y, up), up)
        // A Z-up capture's up vector (0,0,1) lands on +Y; its forward +Y (CAD convention) lands
        // on the engine's forward −Z, so handedness is preserved.
        let zUp = rotate(.z, SIMD3<Float>(0, 0, 1))
        XCTAssertEqual(zUp.x, 0, accuracy: 1e-6); XCTAssertEqual(zUp.y, 1, accuracy: 1e-6); XCTAssertEqual(zUp.z, 0, accuracy: 1e-6)
        let zForward = rotate(.z, SIMD3<Float>(0, 1, 0))
        XCTAssertEqual(zForward.z, -1, accuracy: 1e-6)
        // A training-convention capture's up vector (0,−1,0) lands on +Y.
        XCTAssertEqual(rotate(.negativeY, SIMD3<Float>(0, -1, 0)), up)
        XCTAssertEqual(UntoldGSCaptureUpAxis(rawValue: "-y"), .negativeY)
        XCTAssertEqual(UntoldGSCaptureUpAxis.allCases.map(\.rawValue), ["y", "z", "-y"])

        // Composition order: up-axis first, then scale, yaw about +Y, translation.
        let transform = UntoldGSCookOptions.transform(upAxis: .z, scale: 2, yawDegrees: 90, translation: [10, 0, 0])
        let p = transform * SIMD4<Float>(0, 0, 1, 1) // Z-up "up" → (0,2,0) → yaw keeps Y → (10,2,0)
        XCTAssertEqual(p.x, 10, accuracy: 1e-5); XCTAssertEqual(p.y, 2, accuracy: 1e-5); XCTAssertEqual(p.z, 0, accuracy: 1e-5)
        let q = transform * SIMD4<Float>(1, 0, 0, 1) // +X → scaled (2,0,0) → yaw 90° → (0,0,−2) → (10,0,−2)
        XCTAssertEqual(q.x, 10, accuracy: 1e-5); XCTAssertEqual(q.z, -2, accuracy: 1e-5)
        XCTAssertNoThrow(try UntoldGSCooker.cook(asset: GaussianSplatAsset(splats: [makeSplat(center: .zero)], sphericalHarmonics: nil), options: { var o = UntoldGSCookOptions(); o.transform = transform; return o }()))
    }

    func testNonSimilarityTransformIsRejected() {
        let asset = GaussianSplatAsset(splats: [makeSplat(center: .zero)], sphericalHarmonics: nil)
        var options = UntoldGSCookOptions()
        options.transform = simd_float4x4(diagonal: [1, 2, 1, 1])
        XCTAssertThrowsError(try UntoldGSCooker.cook(asset: asset, options: options)) { error in
            XCTAssertEqual(error as? UntoldGSCookError, .transformIsNotASimilarity)
        }
        options.transform = simd_float4x4(diagonal: [-1, 1, 1, 1]) // mirror
        XCTAssertThrowsError(try UntoldGSCooker.cook(asset: asset, options: options))
    }

    // MARK: - Bake roundtrip

    func testBakeAppliesCookOptionsAndWritesV3() throws {
        let count = 300
        var body = ""
        for index in 0 ..< count {
            let x = Float(index % 10) * 0.1
            let y = Float(index / 10 % 10) * 0.1
            let z = Float(index / 100) * 0.1
            let rest = (0 ..< 9).map { "\(Float($0) * 0.01)" }.joined(separator: " ")
            body += "\(x) \(y) \(z) 0 0 1 0.2 0.1 -0.1 \(rest) 2.0 -4 -4 -4 1 0 0 0\n"
        }
        let header = """
        ply
        format ascii 1.0
        element vertex \(count)
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
        let plyURL = try writeTemporaryFile(Data((header + body).utf8), extension: "ply")
        XCTAssertEqual(try PLYReader.readGaussianSplatCount(from: plyURL), count, "header-only count matches the body")
        let output = try temporaryURL(extension: "untoldgs")

        var options = UntoldGSCookOptions()
        options.log2ChunkSplats = 7 // 128 → 3 chunks
        options.cropMin = [0, 0, 0]
        options.cropMax = [0.95, 0.95, 0.15] // z layers 0 and 0.1 → 200 splats
        options.shDegree = 0
        let result = try bakeGaussianSplatProgressiveTiers(plyURL: plyURL, outputBaseURL: output, lodFractions: [1.0], cookOptions: options)
        XCTAssertEqual(result.cookReport.inputSplatCount, count)
        XCTAssertEqual(result.cookReport.prunedByCrop, 100)
        XCTAssertEqual(result.cookReport.keptSplatCount, 200)
        XCTAssertEqual(result.tiers.count, 1)

        let file = try UntoldGSFile(url: result.tiers[0].url)
        XCTAssertEqual(file.header.version, 3)
        XCTAssertEqual(file.header.splatCount, 200)
        XCTAssertEqual(file.header.log2ChunkSplats, 7)
        XCTAssertEqual(file.index.chunks.count, 2)
        XCTAssertFalse(file.header.hasSphericalHarmonics)
        XCTAssertEqual(file.header.boundingBoxMin, result.boundingBoxMin)
        for splat in try file.decodeAll() {
            XCTAssertLessThanOrEqual(splat.position.z, 0.11)
        }

        // The runtime read path sees the cooked count too.
        XCTAssertEqual(try UntoldGSFormat.read(from: result.tiers[0].url).splatCount, 200)
    }

    // MARK: - Helpers

    private func makeSplat(center: SIMD3<Float>) -> GaussianSplat {
        GaussianSplat(center: SIMD4<Float>(center, 1), scale: [0.01, 0.01, 0.01, 1], color: [1, 1, 1, 1], quat: [1, 0, 0, 0], opacity: 1)
    }

    private func temporaryURL(extension ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("UntoldGSCookerTests-\(UUID().uuidString)")
            .appendingPathExtension(ext)
        temporaryFiles.append(url)
        return url
    }

    private func writeTemporaryFile(_ data: Data, extension ext: String) throws -> URL {
        let url = try temporaryURL(extension: ext)
        try data.write(to: url)
        return url
    }
}
