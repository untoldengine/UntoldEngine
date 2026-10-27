//
//  MSAACentroidEdgeShadingTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import ImageIO
import Metal
import simd
import UniformTypeIdentifiers
@testable import UntoldEngine
import XCTest

/// Under MSAA the model fragment shader runs once per pixel, and without a centroid qualifier
/// its stage-in attributes are evaluated at the pixel's centre, which along a silhouette lies
/// outside the triangle: the normal is extrapolated past the limb, keeps turning toward the
/// back of the surface, and a sun from above lights the dark lower limb of a sphere. The
/// partly covered edge texels then carry the colour of the sphere's sunlit top, and a
/// compositor that blends them by their coverage shows sparse pale dots along the dark edge
/// (the Vision Pro, 2026-10-27). With `[[centroid_perspective]]` on the attributes the GPU
/// evaluates them inside the covered samples and the edge shades like the surface beside it.
///
/// The scene and the eye are the RealityKit presenter's straightness scene: a slab, three
/// cubes and a sphere of radius 6 cm at (0, 1.45, -1.6), the sun overhead at strength 3,
/// drawn under 4x MSAA into the headset's eye texture (1920 by 1824 texels, the presenter's
/// frustum) from an eye at (0, 1.5, 0). The resolved lit colour is read back before the look
/// pass: linear, premultiplied by the coverage the resolve averaged, the alpha the coverage.
/// Along the sphere's bottom arc every partly covered edge texel's straight colour (the
/// colour over the alpha) is compared with the fully covered texel two rows inside.
///
/// Measured on an M-series Mac, 47 edge texels: with the attributes evaluated at the pixel
/// centre the brightest edge texel is 1.35 times the surface two texels in; at the centroid
/// 1.06 times. The extrapolation is small for a smooth surface (the normal turns by the
/// curvature times the distance past the limb, a degree or two here), and what made it the
/// headset's white dots was a decision taken on it: the model pass once turned a normal that
/// pointed away from the viewer, judged on the interpolated normal, and an extrapolated limb
/// normal, a hair past 90 degrees, was turned right round into the sun (13 of the 47 edge
/// texels 2.6 to 7.4 times as bright as the surface beside them, the colour of the sphere's
/// sunlit top). The pass now judges the face itself, from the position's screen derivatives,
/// and the centroid keeps every attribute inside the triangle for whatever is decided on it.
@MainActor
final class MSAACentroidEdgeShadingTests: BaseRenderSetup {
    private var viewportBefore = simd_float2(0, 0)
    private var drawableSizeBefore = CGSize.zero
    private var modeBefore: AntiAliasingMode = .fxaa

    // MARK: - The scene and the eye

    /// The presenter's eye texture and frustum (XRRealityKitPresenterConfiguration's defaults):
    /// the half-angle tangents left, right, top, bottom, the near and far planes.
    private nonisolated static let eyeTextureSize = SIMD2<Int>(1920, 1824)
    private nonisolated static let frustumTangents = SIMD4<Float>(1.30, 1.30, 1.15, 1.30)
    private nonisolated static let nearPlane: Float = 0.05
    private nonisolated static let farPlane: Float = 1000
    private nonisolated static let eyePosition = simd_float3(0, 1.5, 0)

    private nonisolated static let cubeExtent: Float = 0.2
    private nonisolated static let cubeCentreY: Float = 1.025
    private nonisolated static let cubeZ: Float = -1.6
    private nonisolated static let cubeXs: [Float] = [-0.35, 0, 0.35]
    private nonisolated static let sphereCentre = simd_float3(0, 1.45, -1.6)
    private nonisolated static let sphereRadius: Float = 0.06

    /// An edge texel brighter than this many times the texel two in is lit past the limb:
    /// the normal turned round into the sun (2.6 to 7.4 times, measured).
    private nonisolated static let brightnessRatioLimit: Float = 1.5
    /// The brightest edge texel of the arc against the texel two in, with the attributes at
    /// the centroid (1.06 measured); at the pixel centre the extrapolation gave 1.35.
    private nonisolated static let worstRatioLimit: Float = 1.2

    override func initializeAssets() {
        let camera = createEntity()
        createGameCamera(entityId: camera)
        CameraSystem.shared.activeCamera = camera
        cameraLookAt(entityId: camera, eye: Self.eyePosition, target: Self.eyePosition + simd_float3(0, 0, -1), up: simd_float3(0, 1, 0))

        let slab = createEntity()
        setEntityName(entityId: slab, name: "Slab")
        setEntityMeshDirect(entityId: slab, meshes: BasicPrimitives.createCube(extent: 1), assetName: "Slab")
        scaleTo(entityId: slab, scale: simd_float3(1.2, 0.05, 0.6))
        translateTo(entityId: slab, position: simd_float3(0, 0.9, Self.cubeZ))
        updateMaterialRoughness(entityId: slab, roughness: 0.8)
        for (index, x) in Self.cubeXs.enumerated() {
            let cube = createEntity()
            setEntityName(entityId: cube, name: "Cube\(index)")
            setEntityMeshDirect(entityId: cube, meshes: BasicPrimitives.createCube(extent: Self.cubeExtent), assetName: "Cube\(index)")
            translateTo(entityId: cube, position: simd_float3(x, Self.cubeCentreY, Self.cubeZ))
            rotateTo(entityId: cube, angle: Float(index) * 20 - 20, axis: simd_float3(0, 1, 0))
            updateMaterialRoughness(entityId: cube, roughness: 0.4)
            updateMaterialMetallic(entityId: cube, metallic: Float(index) * 0.4)
        }
        let sphere = createEntity()
        setEntityName(entityId: sphere, name: "Sphere")
        setEntityMeshDirect(entityId: sphere, meshes: BasicPrimitives.createSphere(extent: Self.sphereRadius * 2), assetName: "Sphere")
        translateTo(entityId: sphere, position: Self.sphereCentre)
        updateMaterialRoughness(entityId: sphere, roughness: 0.2)
        let sun = createEntity()
        setEntityName(entityId: sun, name: "Sun")
        createDirLight(entityId: sun)
        setLight(entityId: sun, .strength(3))
        renderSkyBackground = false
    }

    override func setUp() async throws {
        try await super.setUp()
        viewportBefore = renderInfo.viewPort
        drawableSizeBefore = renderer.metalView.drawableSize
        modeBefore = antiAliasingMode
        // The eye texture's size and the presenter's projection in place of the window's.
        let size = CGSize(width: Self.eyeTextureSize.x, height: Self.eyeTextureSize.y)
        renderer.metalView.drawableSize = size
        renderer.mtkView(renderer.metalView, drawableSizeWillChange: size)
        renderInfo.viewPort = simd_float2(Float(size.width), Float(size.height))
        renderInfo.perspectiveSpace = Self.reverseZProjection(tangents: Self.frustumTangents, near: Self.nearPlane, far: Self.farPlane)
        TemporalAntiAliasing.shared.projectionDidChange()
        renderer.initSizeableResources()
        renderer.pendingResize = false
    }

    override func tearDown() async throws {
        antiAliasingMode = modeBefore
        updateOpaqueSampleCountForCurrentState()
        renderer.metalView.drawableSize = drawableSizeBefore
        renderInfo.viewPort = viewportBefore
        renderer.initSizeableResources()
        destroyAllEntities()
        try await super.tearDown()
    }

    /// The presenter's projection: right-handed, reverse Z, from the half-angle tangents.
    private nonisolated static func reverseZProjection(tangents: SIMD4<Float>, near: Float, far: Float) -> simd_float4x4 {
        let width = tangents.x + tangents.y
        let height = tangents.z + tangents.w
        let zs = near / (far - near)
        return simd_float4x4(columns: (
            SIMD4<Float>(2 / width, 0, 0, 0),
            SIMD4<Float>(0, 2 / height, 0, 0),
            SIMD4<Float>((tangents.y - tangents.x) / width, (tangents.z - tangents.w) / height, zs, -1),
            SIMD4<Float>(0, 0, zs * far, 0)
        ))
    }

    // MARK: - The eye texture

    /// Linear rgba floats, rows from the top: the resolved lit colour (premultiplied by the
    /// coverage) and the coverage in alpha.
    private struct Picture {
        let width: Int
        let height: Int
        var pixels: [Float]

        func channel(_ x: Int, _ y: Int, _ c: Int) -> Float {
            pixels[(y * width + x) * 4 + c]
        }

        func alpha(_ x: Int, _ y: Int) -> Float {
            channel(x, y, 3)
        }

        /// The colour over the coverage: what the surface was shaded, before the resolve
        /// weighted it by the samples it covers.
        func straightColor(_ x: Int, _ y: Int) -> simd_float3 {
            let a = alpha(x, y)
            guard a > 0.001 else { return .zero }
            return simd_float3(channel(x, y, 0), channel(x, y, 1), channel(x, y, 2)) / a
        }

        func straightLuminance(_ x: Int, _ y: Int) -> Float {
            let c = straightColor(x, y)
            return 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z
        }
    }

    /// The eye drawn under 4x MSAA (three frames, so that nothing of a previous frame's
    /// resources is read), the resolved lit colour read back.
    private func drawEye() throws -> Picture {
        guard renderInfo.device.supportsTextureSampleCount(4) else { throw XCTSkip("this GPU has no 4x MSAA") }
        antiAliasingMode = .msaa
        updateOpaqueSampleCountForCurrentState()
        XCTAssertEqual(renderInfo.opaqueSampleCount, 4, "the opaque pass is multisampled")
        for _ in 0 ..< 3 {
            renderer.draw(in: renderer.metalView)
            renderInfo.lastCommandBuffer?.waitUntilCompleted()
        }
        let texture = try XCTUnwrap(textureResources.deferredColorMap, "the resolved lit colour")
        XCTAssertEqual(texture.pixelFormat, .rgba16Float)
        XCTAssertEqual(texture.width, Self.eyeTextureSize.x)
        XCTAssertEqual(texture.height, Self.eyeTextureSize.y)
        var halves = [UInt16](repeating: 0, count: texture.width * texture.height * 4)
        halves.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: texture.width * 8, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        }
        return Picture(width: texture.width, height: texture.height, pixels: halves.map { Float(Float16(bitPattern: $0)) })
    }

    // MARK: - The sphere's bottom arc

    /// Where the sphere stands on the centre column: the first run of coverage from the top.
    private struct SphereRows {
        let column: Int
        let top: Int
        let bottom: Int
    }

    private func findSphere(in eye: Picture) throws -> SphereRows {
        let column = eye.width / 2
        var top: Int?
        var bottom = 0
        for y in 0 ..< eye.height {
            if eye.alpha(column, y) > 0 {
                if top == nil {
                    top = y
                }
                bottom = y
            } else if top != nil {
                break
            }
        }
        let topRow = try XCTUnwrap(top, "the sphere covers the centre column")
        let rows = SphereRows(column: column, top: topRow, bottom: bottom)
        let height = bottom - topRow + 1
        // Radius 6 cm at 1.6 m, 744 texels per unit tangent: about 56 texels across.
        XCTAssertGreaterThan(height, 40, "the run on the centre column is the sphere (\(height) rows)")
        XCTAssertLessThan(height, 80, "the run on the centre column is the sphere alone (\(height) rows)")
        return rows
    }

    /// One column's lowest edge texel of the sphere against the texel two rows inside it.
    private struct EdgeReading {
        let column: Int
        let row: Int
        let coverage: Float
        let edge: simd_float3
        let inside: simd_float3
        let edgeLuminance: Float
        let insideLuminance: Float

        var ratio: Float {
            edgeLuminance / max(insideLuminance, 0.005)
        }
    }

    /// Along the bottom arc, for every column the sphere covers: the lowest covered texel
    /// where it is partly covered (the MSAA coverage steps) and the texel two rows up is
    /// fully covered. The columns are read within the sphere's rows, so the cubes below are
    /// never reached.
    private func readBottomArc(of eye: Picture, sphere: SphereRows) -> (readings: [EdgeReading], columns: Int) {
        var readings: [EdgeReading] = []
        var columns = 0
        let halfWidth = (sphere.bottom - sphere.top) / 2 + 4
        for x in max(0, sphere.column - halfWidth) ... min(eye.width - 1, sphere.column + halfWidth) {
            var lowest: Int?
            for y in stride(from: min(eye.height - 1, sphere.bottom + 3), through: max(0, sphere.top - 3), by: -1) where eye.alpha(x, y) > 0 {
                lowest = y
                break
            }
            guard let row = lowest else { continue }
            columns += 1
            let coverage = eye.alpha(x, row)
            guard coverage < 0.999, row >= 2, eye.alpha(x, row - 2) >= 0.999 else { continue }
            readings.append(EdgeReading(
                column: x, row: row, coverage: coverage,
                edge: eye.straightColor(x, row), inside: eye.straightColor(x, row - 2),
                edgeLuminance: eye.straightLuminance(x, row), insideLuminance: eye.straightLuminance(x, row - 2)
            ))
        }
        return (readings, columns)
    }

    private nonisolated static func format(_ value: Float, _ digits: Int = 2) -> String {
        String(format: "%.\(digits)f", value)
    }

    private nonisolated static func format(_ color: simd_float3) -> String {
        "(\(format(color.x)), \(format(color.y)), \(format(color.z)))"
    }

    // MARK: - The crop for the eye

    /// The sphere and a margin around it, every texel composited over a mid grey as a
    /// compositor blends it over the room, sRGB-encoded and magnified eightfold, written as a
    /// PNG named `name` into the folder `UNTOLD_MSAA_EDGE_CROP_DIR` names, when it names one.
    private func writeCrop(of eye: Picture, sphere: SphereRows, named name: String) throws {
        guard let folder = ProcessInfo.processInfo.environment["UNTOLD_MSAA_EDGE_CROP_DIR"], !folder.isEmpty else { return }
        let margin = 8
        let halfHeight = (sphere.bottom - sphere.top) / 2 + margin
        let x0 = max(0, sphere.column - halfHeight), x1 = min(eye.width - 1, sphere.column + halfHeight)
        let y0 = max(0, sphere.top - margin), y1 = min(eye.height - 1, sphere.bottom + margin)
        let scale = 8
        let width = (x1 - x0 + 1) * scale, height = (y1 - y0 + 1) * scale
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        func encode(_ linear: Float) -> UInt8 {
            // A texel that is not a number is shown white, so that it stands out.
            guard linear.isFinite else { return 255 }
            let v = min(max(linear, 0), 1)
            let s = v <= 0.0031308 ? v * 12.92 : 1.055 * pow(v, 1 / 2.4) - 0.055
            return UInt8(clamping: Int((s * 255).rounded()))
        }
        let room: Float = 0.5
        for y in 0 ..< height {
            for x in 0 ..< width {
                let tx = x0 + x / scale, ty = y0 + y / scale
                let a = eye.alpha(tx, ty)
                let base = (y * width + x) * 4
                for c in 0 ..< 3 {
                    bytes[base + c] = encode(eye.channel(tx, ty, c) + (1 - a) * room)
                }
                bytes[base + 3] = 255
            }
        }
        try writePNG(bytes, width: width, height: height, to: folder, named: name)
        // The same texels as the surface was shaded: the straight colour wherever anything
        // was drawn (a partly covered texel shown whole), the room elsewhere.
        for y in 0 ..< height {
            for x in 0 ..< width {
                let tx = x0 + x / scale, ty = y0 + y / scale
                let base = (y * width + x) * 4
                if eye.alpha(tx, ty) > 0.001 {
                    let straight = eye.straightColor(tx, ty)
                    bytes[base] = encode(straight.x)
                    bytes[base + 1] = encode(straight.y)
                    bytes[base + 2] = encode(straight.z)
                } else {
                    for c in 0 ..< 3 {
                        bytes[base + c] = encode(room)
                    }
                }
            }
        }
        try writePNG(bytes, width: width, height: height, to: folder, named: "\(name)-straight")
    }

    private func writePNG(_ bytes: [UInt8], width: Int, height: Int, to folder: String, named name: String) throws {
        let url = URL(fileURLWithPath: folder, isDirectory: true).appendingPathComponent("\(name).png")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = Data(bytes)
        let image = try XCTUnwrap(CGDataProvider(data: data as CFData).flatMap { provider in
            CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                    provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        })
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination), "the crop is written")
        print("MSAA edge shading: crop written to \(url.path)")
    }

    // MARK: - The test

    func testSphereBottomArcEdgeTexelsShadeLikeTheSurfaceBesideThem() throws {
        let eye = try drawEye()
        let nonFinite = (0 ..< eye.width * eye.height).filter { i in (0 ..< 4).contains { !eye.pixels[i * 4 + $0].isFinite } }
        print("MSAA edge shading: \(nonFinite.count) texels of \(eye.width) x \(eye.height) are not finite" + (nonFinite.isEmpty ? "" : "; the first " + nonFinite.prefix(8).map { i in "(\(i % eye.width), \(i / eye.width)) = (\((0 ..< 4).map { "\(eye.pixels[i * 4 + $0])" }.joined(separator: ", ")))" }.joined(separator: " ")))
        XCTAssertEqual(nonFinite.count, 0, "every texel of the resolved lit colour is finite")
        let sphere = try findSphere(in: eye)
        try writeCrop(of: eye, sphere: sphere, named: "sphere-lower-limb")
        let arc = readBottomArc(of: eye, sphere: sphere)
        print("MSAA edge shading: the sphere on column \(sphere.column) from row \(sphere.top) to \(sphere.bottom); \(arc.columns) columns along its bottom arc, \(arc.readings.count) with a partly covered edge texel over a fully covered texel two rows in")

        XCTAssertGreaterThan(arc.columns, 40, "the sphere spans the columns read")
        XCTAssertGreaterThan(arc.readings.count, 20, "the bottom arc has partly covered edge texels")

        let coverages = Set(arc.readings.map { Int(($0.coverage * 4).rounded()) })
        print("MSAA edge shading: coverage steps seen \(coverages.sorted().map { "\($0)/4" }.joined(separator: ", "))")

        let overLimit = arc.readings.filter { $0.ratio > Self.brightnessRatioLimit }
        let worst = arc.readings.max { $0.ratio < $1.ratio }
        let meanEdge = arc.readings.reduce(simd_float3.zero) { $0 + $1.edge } / Float(max(arc.readings.count, 1))
        let meanInside = arc.readings.reduce(simd_float3.zero) { $0 + $1.inside } / Float(max(arc.readings.count, 1))
        print("MSAA edge shading: mean straight colour of the edge texels \(Self.format(meanEdge)), of the texels two in \(Self.format(meanInside))")
        for reading in overLimit {
            print("MSAA edge shading: column \(reading.column) row \(reading.row) coverage \(Self.format(reading.coverage)): edge \(Self.format(reading.edge)) (luminance \(Self.format(reading.edgeLuminance, 3))) against \(Self.format(reading.inside)) two in (\(Self.format(reading.insideLuminance, 3))), \(Self.format(reading.ratio, 1))x")
        }
        let ratios = arc.readings.map(\.ratio)
        let meanRatio = ratios.reduce(0, +) / Float(max(ratios.count, 1))
        let overTenth = ratios.filter { $0 > 1.1 }.count
        print("MSAA edge shading: \(overLimit.count) of \(arc.readings.count) edge texels over \(Self.format(Self.brightnessRatioLimit, 1))x the texel two in, \(overTenth) over 1.1x; the mean ratio \(Self.format(meanRatio, 3)), the worst \(Self.format(worst?.ratio ?? 0, 2))x at column \(worst?.column ?? -1)")

        XCTAssertEqual(overLimit.count, 0, "no partly covered edge texel along the sphere's dark bottom arc is over \(Self.format(Self.brightnessRatioLimit, 1))x as bright as the surface two texels in (\(overLimit.count) of \(arc.readings.count) are: a normal extrapolated past the limb was turned into the sun)")
        XCTAssertLessThanOrEqual(worst?.ratio ?? 0, Self.worstRatioLimit, "the brightest edge texel of the arc is within \(Self.format(Self.worstRatioLimit, 1))x of the surface two texels in (the attributes are evaluated inside the triangle: 1.06x at the centroid, 1.35x at the pixel centre)")
    }
}
