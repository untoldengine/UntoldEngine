//
//  MaterialShadingTestCase.swift
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

/// A shape in front of the camera under one directional light, for tests that read how
/// the engine shades a material: build the scene, hand it a material, read the lit color.
class MaterialShadingTestCase: BaseRenderSetup {
    enum Shape {
        /// A cube whose front face looks at the camera and fills the middle of the frame.
        case cube
        /// A sphere in the middle of the frame, about a third of its height across.
        case sphere
    }

    private var subject: EntityID = .invalid
    private var hasItsOwnEnvironment = false

    override func tearDown() async throws {
        destroyAllEntities()
        subject = .invalid
        if hasItsOwnEnvironment {
            // The bake of this test's environment went into the textures the engine keeps
            // for the default one: drop them, so the next test bakes its own again.
            invalidateIBLBakeCache()
            hasItsOwnEnvironment = false
        }
        try await super.tearDown()
    }

    override func initializeAssets() {
        // Each test builds its own scene.
    }

    /// The camera at (0, 0, 5) looking at the origin, the light coming from the right
    /// at 45 degrees (pass nil for no light), and the shape at the origin.
    func buildScene(_ shape: Shape = .cube, towardsLight: simd_float3? = simd_float3(1, 0, 1)) throws {
        let camera = createEntity()
        createGameCamera(entityId: camera)
        CameraSystem.shared.activeCamera = camera
        cameraLookAt(entityId: camera, eye: simd_float3(0, 0, 5), target: .zero, up: simd_float3(0, 1, 0))

        // The renderer starts with a directional light of its own, straight overhead, and
        // a new light takes over only when there is none: retire it, so that the scene is
        // lit by what the test asks for and by nothing else.
        LightingSystem.shared.activeDirectionalLight = nil
        if let towardsLight {
            let sun = createEntity()
            createDirLight(entityId: sun)
            rotateTo(entityId: sun, rotation: quaternion_lookAt(eye: simd_normalize(towardsLight), target: .zero, up: simd_float3(0, 1, 0)))
            XCTAssertEqual(LightingSystem.shared.activeDirectionalLight, sun)
        }

        subject = createEntity()
        let meshes: [Mesh] = switch shape {
        case .cube: BasicPrimitives.createCube(extent: 3.0)
        case .sphere: BasicPrimitives.createSphere(extent: 2.0, segments: [64, 32])
        }
        let renderComponent = try XCTUnwrap(scene.assign(to: subject, component: RenderComponent.self))
        renderComponent.mesh = meshes
        renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/material-shading-subject.untold")
        if let local = scene.get(component: LocalTransformComponent.self, for: subject) {
            local.boundingBox = Mesh.computeMeshBoundingBox(for: meshes)
        }
        setVisibleEntities()
    }

    /// Lights the scene with an environment that is equally bright all around, and with
    /// nothing else. What a surface then shows is the share of that light it gives back:
    /// one that gives back all of it comes out as bright as a matte white one.
    func lightWithAnEvenEnvironment() throws {
        // A Radiance picture of one value: 0.5 is a mantissa of 128 with an exponent of 128.
        let width = 64
        let height = 32
        var picture = Data("#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n-Y \(height) +X \(width)\n".utf8)
        for _ in 0 ..< width * height {
            picture.append(contentsOf: [128, 128, 128, 128])
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("even-environment-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        try picture.write(to: folder.appendingPathComponent("even.hdr"))

        hasItsOwnEnvironment = true
        generateHDR("even.hdr", from: folder)
        XCTAssertTrue(iblSuccessful, "the even environment was baked")
        applyIBL = true
        ambientIntensity = 1.0
    }

    /// Draws the shape with the material and returns the lit frame, in linear values:
    /// `width` x `height` pixels of red, green, blue.
    func shadeFrame(_ source: RuntimeMaterialSource) throws -> (pixels: [simd_float3], width: Int, height: Int) {
        if subject == .invalid {
            try buildScene()
        }
        let material = Material(runtimeMaterial: source, device: renderInfo.device)
        let renderComponent = try XCTUnwrap(scene.get(component: RenderComponent.self, for: subject))
        for meshIndex in renderComponent.mesh.indices {
            for submeshIndex in renderComponent.mesh[meshIndex].submeshes.indices {
                renderComponent.mesh[meshIndex].submeshes[submeshIndex].material = material
            }
        }

        // Seeded again for every frame: without a culling pass feeding it, the visible
        // list of an earlier frame is not kept.
        setVisibleEntities()
        renderer.draw(in: renderer.metalView)
        let rendered = XCTestExpectation(description: "Lit frame")
        var frame: (pixels: [simd_float3], width: Int, height: Int) = ([], 0, 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            defer { rendered.fulfill() }
            guard let texture = textureResources.deferredColorMap, texture.pixelFormat == .rgba16Float else {
                XCTFail("Expected an rgba16Float deferred color target")
                return
            }
            var raw = [Float16](repeating: 0, count: texture.width * texture.height * 4)
            texture.getBytes(
                &raw, bytesPerRow: texture.width * 8,
                from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0
            )
            var pixels = [simd_float3](repeating: .zero, count: texture.width * texture.height)
            for index in pixels.indices {
                pixels[index] = simd_float3(Float(raw[index * 4]), Float(raw[index * 4 + 1]), Float(raw[index * 4 + 2]))
            }
            frame = (pixels, texture.width, texture.height)
        }
        wait(for: [rendered], timeout: TimeInterval(timeoutFactor))
        return frame
    }

    /// The lit color in the middle of the frame: the mean of a 16-pixel window.
    func shade(_ source: RuntimeMaterialSource) throws -> simd_float3 {
        let frame = try shadeFrame(source)
        return Self.meanColor(of: frame, aroundX: frame.width / 2, y: frame.height / 2, window: 16)
    }

    static func meanColor(of frame: (pixels: [simd_float3], width: Int, height: Int), aroundX x: Int, y: Int, window: Int) -> simd_float3 {
        var sum = simd_float3(repeating: 0)
        for row in (y - window / 2) ..< (y + window / 2) {
            for column in (x - window / 2) ..< (x + window / 2) {
                sum += frame.pixels[row * frame.width + column]
            }
        }
        return sum / Float(window * window)
    }

    /// An 8 x 8 grayscale PNG of one value: a single channel of 8 bits, the way an
    /// exporter writes a texture whose red, green and blue are the same.
    func writeGrayscaleTexture(value: UInt8) throws -> URL {
        let size = 8
        var pixels = [UInt8](repeating: value, count: size * size)
        let context = try XCTUnwrap(CGContext(
            data: &pixels, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ))
        let image = try XCTUnwrap(context.makeImage())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("texture-gray-\(value)-\(UUID().uuidString).png")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    /// An 8 x 8 PNG of one color, 8 bits per channel, as an exporter writes a texture.
    func writeTexture(red: UInt8, green: UInt8, blue: UInt8) throws -> URL {
        let size = 8
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        for index in 0 ..< size * size {
            pixels[index * 4] = red
            pixels[index * 4 + 1] = green
            pixels[index * 4 + 2] = blue
            pixels[index * 4 + 3] = 255
        }
        let context = try XCTUnwrap(CGContext(
            data: &pixels, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        let image = try XCTUnwrap(context.makeImage())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("texture-\(red)-\(green)-\(blue)-\(UUID().uuidString).png")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
