//
//  TBDREmissiveCompositeTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Metal
import simd
@testable import UntoldEngine
import XCTest

/// Regression test for the TBDR light pass zeroing G-buffer emissive before
/// compositing: material emissive must reach the deferred lit output.
final class TBDREmissiveCompositeTest: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        try await super.tearDown()
        destroyAllEntities()
    }

    override func initializeAssets() {}

    private func renderFrame() {
        setVisibleEntities()
        renderer.draw(in: renderer.metalView)

        let frameDone = expectation(description: "Frame rendered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { frameDone.fulfill() }
        wait(for: [frameDone], timeout: TimeInterval(timeoutFactor))
    }

    private func halfToFloat(_ half: UInt16) -> Float {
        let sign = UInt32(half >> 15) & 0x1
        let exponent = UInt32(half >> 10) & 0x1F
        var mantissa = UInt32(half) & 0x3FF

        let bits: UInt32
        if exponent == 0 {
            if mantissa == 0 {
                bits = sign << 31
            } else {
                var e: UInt32 = 127 - 15 + 1
                while mantissa & 0x400 == 0 {
                    mantissa <<= 1
                    e -= 1
                }
                bits = (sign << 31) | (e << 23) | ((mantissa & 0x3FF) << 13)
            }
        } else if exponent == 0x1F {
            bits = (sign << 31) | (0xFF << 23) | (mantissa << 13)
        } else {
            bits = (sign << 31) | ((exponent + 127 - 15) << 23) | (mantissa << 13)
        }
        return Float(bitPattern: bits)
    }

    /// Average color of a small region at the center of an rgba16Float texture.
    private func centerAverageColor(of texture: MTLTexture, regionSize: Int = 16) throws -> simd_float3 {
        XCTAssertEqual(texture.pixelFormat, .rgba16Float)
        XCTAssertNotEqual(texture.storageMode, .private, "Texture must be CPU-readable")

        let originX = texture.width / 2 - regionSize / 2
        let originY = texture.height / 2 - regionSize / 2
        var data = [UInt16](repeating: 0, count: regionSize * regionSize * 4)
        data.withUnsafeMutableBytes { buffer in
            texture.getBytes(
                buffer.baseAddress!,
                bytesPerRow: regionSize * 8,
                from: MTLRegionMake2D(originX, originY, regionSize, regionSize),
                mipmapLevel: 0
            )
        }

        var sum = simd_float3.zero
        for pixel in 0 ..< (regionSize * regionSize) {
            let base = pixel * 4
            sum += simd_float3(
                halfToFloat(data[base]),
                halfToFloat(data[base + 1]),
                halfToFloat(data[base + 2])
            )
        }
        return sum / Float(regionSize * regionSize)
    }

    /// Renders a screen-filling cube twice — without and with red material
    /// emissive — and asserts the lit output's red channel brightens, so a
    /// light shader that zeroes G-buffer emissive fails this test.
    func testEmissiveMaterialReachesLitOutput() throws {
        let camera = findGameCamera()
        cameraLookAt(entityId: camera, eye: simd_float3(0, 0, 3), target: .zero, up: simd_float3(0, 1, 0))

        let cube = createEntity()
        setEntityMeshDirect(entityId: cube, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "EmissiveCube")

        renderFrame()
        let litOutput = try XCTUnwrap(textureResources.deferredColorMap, "Deferred color map should exist")
        let baseline = try centerAverageColor(of: litOutput)

        updateMaterialEmmisive(entityId: cube, emmissive: simd_float3(3, 0, 0))
        renderFrame()
        let withEmissive = try centerAverageColor(of: litOutput)

        XCTAssertGreaterThan(withEmissive.x, baseline.x + 0.1,
                             "Red emissive must be composited into the TBDR light pass output")
        XCTAssertEqual(withEmissive.y, baseline.y, accuracy: 0.05,
                       "Red-only emissive should not brighten the green channel")
        XCTAssertEqual(withEmissive.z, baseline.z, accuracy: 0.05,
                       "Red-only emissive should not brighten the blue channel")
    }
}
