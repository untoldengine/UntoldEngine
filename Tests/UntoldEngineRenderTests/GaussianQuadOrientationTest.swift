//
//  GaussianQuadOrientationTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd
@testable import UntoldEngine
import XCTest

/// The rendered quad of a splat follows its projected ellipse whatever the tilt: the quad's
/// axes come from the conic in the pixel frame (y down) and the vertex shader offsets the
/// quad in NDC (y up), so the y offset has to flip on the way. Without the flip a tilted
/// ellipse gets the mirror image of its quad and the falloff is clipped to the overlap of
/// the two, which for a thin splat is a small square at the centre. The alpha a splat
/// deposits on the layer is the integral of its falloff, invariant under a rotation of the
/// ellipse, so the same thin ellipse drawn flat and drawn at 45 degrees must deposit the
/// same alpha.
final class GaussianQuadOrientationTest: BaseRenderSetup {
    private var fixtures: [EntityID] = []
    private var savedHZB = false

    override func setUp() async throws {
        try await super.setUp()
        savedHZB = GaussianDebugOptions.shared.disableHZBOcclusionCull
        GaussianDebugOptions.shared.disableHZBOcclusionCull = true
    }

    override func tearDown() async throws {
        for entity in fixtures where scene.exists(entity) {
            removeEntityGaussian(entityId: entity)
        }
        fixtures.removeAll()
        destroyAllEntities()
        GaussianDebugOptions.shared.disableHZBOcclusionCull = savedHZB
        try await super.tearDown()
    }

    override func initializeAssets() {}

    /// Two copies of one thin ellipse (aspect 7.5:1), white, opacity 0.9: the left one flat
    /// (long axis along x), the right one rotated 45 degrees about the view axis. Far enough
    /// apart that their quads never overlap, close enough to the camera that neither hits the
    /// screen-radius clamp.
    private func writeFixture() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaussianQuadOrientation-\(UUID().uuidString)")
            .appendingPathExtension("untoldgs")
        let scale = simd_float3(0.12, 0.016, 0.016)
        let splats = [
            UntoldGSSplat(position: simd_float3(-1.2, 0, 0), scale: scale, rotation: simd_quatf(angle: 0, axis: simd_float3(0, 0, 1)), color: simd_float3(1, 1, 1), opacity: 0.9, sphericalHarmonics: []),
            UntoldGSSplat(position: simd_float3(1.2, 0, 0), scale: scale, rotation: simd_quatf(angle: .pi / 4, axis: simd_float3(0, 0, 1)), color: simd_float3(1, 1, 1), opacity: 0.9, sphericalHarmonics: []),
        ]
        var options = UntoldGSWriteOptions()
        options.log2ChunkSplats = 10
        options.coarseLevelsAutomatic = false
        try UntoldGSFormat.write(splats: splats, options: options, to: url)
        return url
    }

    func testTiltedSplatDepositsTheSameAlphaAsTheFlatOne() throws {
        let url = try writeFixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let entity = createEntity()
        fixtures.append(entity)
        setEntityGaussian(entityId: entity, filename: url.deletingPathExtension().path, withExtension: "untoldgs")
        XCTAssertNotNil(scene.get(component: GaussianComponent.self, for: entity), "the fixture loads")
        placeGaussianTestCamera(eye: simd_float3(0, 0, 5), target: .zero)

        var layer: [Float16] = []
        for _ in 0 ..< 2 {
            layer = renderGaussianSplatLayer()
        }
        let texture = try XCTUnwrap(renderInfo.gaussianRenderPassDescriptor.colorAttachments[0].texture)
        let width = texture.width
        let height = texture.height
        var flat: Double = 0
        var tilted: Double = 0
        var flatPixels = 0
        var tiltedPixels = 0
        for y in 0 ..< height {
            for x in 0 ..< width {
                let alpha = Double(layer[(y * width + x) * 4 + 3])
                guard alpha > 0 else { continue }
                if x < width / 2 {
                    flat += alpha
                    flatPixels += 1
                } else {
                    tilted += alpha
                    tiltedPixels += 1
                }
            }
        }
        XCTAssertGreaterThan(flatPixels, 50, "the flat splat covers pixels")
        XCTAssertGreaterThan(tiltedPixels, 50, "the tilted splat covers pixels")
        XCTAssertGreaterThan(flat, 50, "the flat splat deposits alpha")
        // A mirrored quad clips the tilted splat to about a quarter of its alpha; the two
        // rasterisations of one ellipse otherwise differ only by pixel sampling.
        XCTAssertEqual(tilted, flat, accuracy: flat * 0.05, "the tilted ellipse deposits the alpha of the flat one (flat \(flat), tilted \(tilted))")
    }
}
