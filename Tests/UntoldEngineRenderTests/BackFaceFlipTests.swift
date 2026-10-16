//
//  BackFaceFlipTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Metal
import MetalKit
import ModelIO
import simd
@testable import UntoldEngine
import XCTest

/// The model pass turns the normal of a face that points away from the viewer, so an open mesh
/// seen from behind is lit. The decision is made on the face, not on the interpolated normal: a
/// front face whose vertex normals are averaged across hard edges (a kit's box with corner
/// normals 55° off the face) has interpolated normals that pass 90° from the viewer before the
/// far edge, and deciding on them turned a strip of every such face dark.
///
/// One quad under an image light that comes from a cap around its face normal and from nowhere
/// else, seen from above at a grazing angle, on the forward path:
/// - with its normals averaged outwards (45° off the face) it is lit all over, as the same quad
///   with flat normals is: no strip goes dark near its far edge;
/// - with its normals pointing away from the viewer (the back of an open sheet) it is lit all
///   over too: the flip still turns a true back face.
@MainActor
final class BackFaceFlipTests: BaseRenderSetup {
    private var savedPath: RenderPath = .deferred
    private var savedMode: AntiAliasingMode = .fxaa
    private var savedHDR = ""
    private var camera: EntityID = .max
    private var quad: EntityID = .max
    private var hdrDirectory: URL?

    override func setUp() async throws {
        try await super.setUp()
        savedPath = getRenderPath()
        savedMode = antiAliasingMode
    }

    override func tearDown() async throws {
        setRendering(.renderPath(savedPath))
        antiAliasingMode = savedMode
        destroyAllEntities()
        if let hdrDirectory {
            try? FileManager.default.removeItem(at: hdrDirectory)
        }
        try await super.tearDown()
    }

    override func initializeAssets() {
        camera = createEntity()
        createGameCamera(entityId: camera)
        CameraSystem.shared.activeCamera = camera
        // Above the quad, 25° over its plane, looking at its centre: the far edge is at grazing.
        cameraLookAt(entityId: camera, eye: simd_float3(0, 1.2, 2.6), target: simd_float3(0, 0, 0), up: simd_float3(0, 1, 0))
        applyIBL = true
        ambientIntensity = 1.0
        renderEnvironment = false
    }

    // MARK: - The light: a cap around the zenith

    /// An equirectangular image, bright within 40° of the zenith and black elsewhere, written as
    /// an uncompressed Radiance file and baked as the image light. A normal tilted 45° off the
    /// zenith still faces the whole cap; one turned 45° below the horizon faces none of it.
    private func lightTheZenithCap() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("BackFaceFlipTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        hdrDirectory = directory
        let width = 128, height = 64
        var data = Data("#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n-Y \(height) +X \(width)\n".utf8)
        for row in 0 ..< height {
            // Row 0 is the zenith, the last row the nadir: 180° over the height.
            let elevation = 90.0 - 180.0 * (Double(row) + 0.5) / Double(height)
            let texel: [UInt8] = elevation > 50.0 ? [128, 128, 128, 129] : [0, 0, 0, 0] // 128/256 * 2^(129-128) = 1.0
            for _ in 0 ..< width {
                data.append(contentsOf: texel)
            }
        }
        let name = "zenithCap.hdr"
        try data.write(to: directory.appendingPathComponent(name))
        generateHDR(name, from: directory)
    }

    // MARK: - The quad

    /// ModelIO packs a float3 attribute in 12 bytes: read and written as three floats.
    private func float3(at pointer: UnsafeMutableRawPointer) -> simd_float3 {
        simd_float3(pointer.loadUnaligned(as: Float.self),
                    pointer.loadUnaligned(fromByteOffset: 4, as: Float.self),
                    pointer.loadUnaligned(fromByteOffset: 8, as: Float.self))
    }

    private func store(_ value: simd_float3, at pointer: UnsafeMutableRawPointer) {
        pointer.storeBytes(of: value.x, as: Float.self)
        pointer.storeBytes(of: value.y, toByteOffset: 4, as: Float.self)
        pointer.storeBytes(of: value.z, toByteOffset: 8, as: Float.self)
    }

    private enum Normals { case flat, averagedOutwards, turnedAway }

    /// A 2 m square in the XZ plane with its face normal +Y, and the vertex normals asked for.
    private func makeQuad(_ normals: Normals) -> [Mesh] {
        let allocator = MTKMeshBufferAllocator(device: renderInfo.device)
        let mdlMesh = MDLMesh(planeWithExtent: [2, 0, 2], segments: [1, 1], geometryType: .triangles, allocator: allocator)
        mdlMesh.name = "FlipQuad"
        guard let positions = mdlMesh.vertexAttributeData(forAttributeNamed: MDLVertexAttributePosition, as: .float3),
              let normalData = mdlMesh.vertexAttributeData(forAttributeNamed: MDLVertexAttributeNormal, as: .float3)
        else {
            XCTFail("the plane has no positions or normals")
            return []
        }
        // The plane's own face normal, read from its first vertex; every vertex of a flat plane
        // carries it. The vertex normals are then written per vertex from the position:
        // averaged outwards = halfway between the face normal and the direction to the corner.
        let faceNormal = simd_normalize(float3(at: normalData.dataStart))
        for i in 0 ..< mdlMesh.vertexCount {
            let position = float3(at: positions.dataStart.advanced(by: i * positions.stride))
            let normal: simd_float3
            switch normals {
            case .flat: normal = faceNormal
            case .averagedOutwards:
                let toCorner = simd_normalize(position - simd_dot(position, faceNormal) * faceNormal)
                normal = simd_normalize(faceNormal + toCorner) // 45° off the face
            case .turnedAway: normal = -faceNormal
            }
            store(normal, at: normalData.dataStart.advanced(by: i * normalData.stride))
        }
        return BasicPrimitives.createMesh(from: mdlMesh)
    }

    /// Places the quad so that its face normal is +Y whatever ModelIO's plane orientation.
    private func placeQuad(_ normals: Normals) {
        if quad != .max {
            destroyEntity(entityId: quad)
        }
        quad = createEntity()
        let meshes = makeQuad(normals)
        XCTAssertFalse(meshes.isEmpty)
        setEntityMeshDirect(entityId: quad, meshes: meshes, assetName: "FlipQuad")
        let allocator = MTKMeshBufferAllocator(device: renderInfo.device)
        let probe = MDLMesh(planeWithExtent: [2, 0, 2], segments: [1, 1], geometryType: .triangles, allocator: allocator)
        if let normalData = probe.vertexAttributeData(forAttributeNamed: MDLVertexAttributeNormal, as: .float3) {
            let faceNormal = simd_normalize(float3(at: normalData.dataStart))
            if simd_dot(faceNormal, simd_float3(0, 1, 0)) < 0.999 {
                rotateTo(entityId: quad, rotation: simd_quatf(from: faceNormal, to: simd_float3(0, 1, 0)))
            }
        }
        setVisibleEntities()
    }

    // MARK: - Reading the frame

    private func drawFrames(_ count: Int = 3) {
        for _ in 0 ..< count {
            renderer.draw(in: renderer.metalView)
            renderInfo.lastCommandBuffer?.waitUntilCompleted()
        }
    }

    /// The frame's luminance per pixel.
    private func luminance() throws -> [Float] {
        drawFrames()
        let texture = try XCTUnwrap(textureResources.deferredColorMap)
        var halves = [UInt16](repeating: 0, count: texture.width * texture.height * 4)
        halves.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: texture.width * 8, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        }
        return (0 ..< texture.width * texture.height).map { i in
            (Float(Float16(bitPattern: halves[i * 4])) + Float(Float16(bitPattern: halves[i * 4 + 1])) + Float(Float16(bitPattern: halves[i * 4 + 2]))) / 3
        }
    }

    /// The quad's footprint: the pixels the flat quad lights above a quarter of its brightest.
    private func footprint(of flat: [Float]) -> (pixels: [Int], brightest: Float) {
        let brightest = flat.max() ?? 0
        return ((0 ..< flat.count).filter { flat[$0] > brightest * 0.25 }, brightest)
    }

    /// The pixels of the footprint that `frame` leaves dark: below half of the flat quad's
    /// brightest. Measured on an M-series Mac: every normal within 45° of the face, and a turned
    /// back face, light their dimmest pixel to 99 % of it or more; a normal the old test turned
    /// below the horizon lit its strip to 34–50 % of it, over 12 % of the quad's pixels.
    private func darkPixels(in frame: [Float], footprint: (pixels: [Int], brightest: Float)) -> Int {
        let dark = footprint.pixels.filter { frame[$0] < footprint.brightest * 0.5 }.count
        let dimmest = footprint.pixels.map { frame[$0] }.min() ?? 0
        print(String(format: "Back-face flip: %d of the quad's %d pixels below half the flat quad's brightest; dimmest %.3f of %.3f", dark, footprint.pixels.count, dimmest, footprint.brightest))
        return dark
    }

    // MARK: - Tests

    func testAveragedNormalsLeaveNoDarkStripOnAFrontFace() throws {
        try lightTheZenithCap()
        setRendering(.renderPath(.forward))
        antiAliasingMode = .none

        placeQuad(.flat)
        let flat = try footprint(of: luminance())
        XCTAssertGreaterThan(flat.pixels.count, 20000, "the quad is on screen and lit (brightest \(flat.brightest))")

        placeQuad(.averagedOutwards)
        let dark = try darkPixels(in: luminance(), footprint: flat)
        print("Back-face flip: the quad covers \(flat.pixels.count) pixels; with averaged normals \(dark) of them are dark")
        XCTAssertLessThan(dark, flat.pixels.count / 200, "a front face with averaged normals is lit all over; deciding the flip on the interpolated normal left its far strip dark (measured 12 % of the quad)")
    }

    func testABackFaceIsStillTurnedTowardsTheViewer() throws {
        try lightTheZenithCap()
        setRendering(.renderPath(.forward))
        antiAliasingMode = .none

        placeQuad(.flat)
        let flat = try footprint(of: luminance())
        XCTAssertGreaterThan(flat.pixels.count, 20000, "the quad is on screen and lit (brightest \(flat.brightest))")

        placeQuad(.turnedAway)
        let dark = try darkPixels(in: luminance(), footprint: flat)
        print("Back-face flip: the quad covers \(flat.pixels.count) pixels; with its normals turned away \(dark) of them are dark")
        XCTAssertLessThan(dark, flat.pixels.count / 200, "a face whose normals point away from the viewer is lit with them turned around")
    }
}
