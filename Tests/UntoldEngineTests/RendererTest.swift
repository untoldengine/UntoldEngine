//
//  RendererTest.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 12/30/24.

import simd
@testable import UntoldEngine
import XCTest

final class RendererTests: XCTestCase {
    var renderer: UntoldRenderer!
    var window: NSWindow!

    override func setUp() {
        super.setUp()
        let windowWidth = 1280
        let windowHeight = 720
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)

        window.title = "Test Window"

        // Initialize the renderer
        guard let renderer = UntoldRenderer.create() else {
            XCTFail("Failed to initialize the renderer.")
            return
        }

        window.contentView = renderer.metalView

        self.renderer = renderer

        // Initialize resources
        self.renderer.initResources()

        // Initialize projection
        let aspect = Float(windowWidth) / Float(windowHeight)
        let projectionMatrix = matrixPerspectiveRightHand(
            fovyRadians: degreesToRadians(degrees: fov),
            aspectRatio: aspect,
            nearZ: near,
            farZ: far
        )

        renderInfo.perspectiveSpace = projectionMatrix

        let viewPortSize: simd_float2 = simd_make_float2(Float(windowWidth), Float(windowHeight))
        renderInfo.viewPort = viewPortSize

        // Initialize assets
        initializeAssets()
        renderEnvironment = true
    }

    override func tearDown() {
        super.tearDown()
    }

    func testRendererInitialization() {
        XCTAssertNotNil(renderer, "Renderer should be inialized.")
    }

    func testProjectionMatrixInitialization() {
        // Known parameters
        let windowWidth: Float = 1280
        let windowHeight: Float = 720
        let far: Float = far
        let near: Float = near
        let fov: Float = fov

        // Aspect ratio
        let aspect = windowWidth / windowHeight

        // Compute the expected projection matrix
        let expectedProjectionMatrix = matrixPerspectiveRightHand(
            fovyRadians: degreesToRadians(degrees: fov),
            aspectRatio: aspect,
            nearZ: near,
            farZ: far
        )

        // Compare with the initialized projection matrix in the renderer
        let actualProjectionMatrix = renderInfo.perspectiveSpace

        // Assert that the matrices are close enough
        XCTAssertTrue(compareMatrices(actualProjectionMatrix, expectedProjectionMatrix), "Projection matrix is incorrect.")

        // Check viewport dimensions
        let expectedViewport = simd_make_float2(windowWidth, windowHeight)
        XCTAssertEqual(renderInfo.viewPort, expectedViewport, "Viewport dimensions are incorrect.")
    }

    // Uncomment this code snippet to generate a reference image

    func testGenerateReferenceImage() {
        // Ensure renderer and metalview are properly initialized
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        // Manually trigger the draw call
        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "Render graph execution delay")
        let downloadDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let outputImage = textureToCGImage(texture: renderInfo.renderPassDescriptor.colorAttachments[0].texture!)

            saveCGImageToDisk(outputImage!, fileName: "ReferenceImage", directory: downloadDirectory)

            XCTAssertNotNil(outputImage, "Renderer should produce an output image")

            expectation.fulfill()
        }

        // Wait for the execution
        wait(for: [expectation], timeout: 2.0)
    }

    func testRenderOutput() {
        // Ensure renderer and metalview are properly initialized
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        // load reference image
        guard let referenceImage = loadReferenceImage() else {
            XCTFail("Failed to load reference image for comparison.")

            return
        }

        // Manually trigger the draw call
        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "Render graph execution delay")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let renderedImage = textureToCGImage(texture: renderInfo.renderPassDescriptor.colorAttachments[0].texture!)

            XCTAssertNotNil(renderedImage, "Renderer should produce an output image")

            let difference = self.compareImages(renderedImage!, referenceImage)
            XCTAssert(difference < 1e-3, "Images are not similar enough. Difference: \(difference)")

            expectation.fulfill()
        }

        // Wait for the execution
        wait(for: [expectation], timeout: 2.0)
    }

    // Utility to load reference image
    private func loadReferenceImage() -> CGImage? {
        // Load the reference CGImage from file
        guard let url = Bundle.module.url(forResource: "ReferenceImage", withExtension: "png") else {
            print("Error: Reference image file not found in bundle.")
            return nil
        }

        guard let cgImageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            print("Error: Failed to create CGImage source.")
            return nil
        }

        guard let cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) else {
            print("Error: Failed to create CGImage from source.")
            return nil
        }

        return cgImage
    }

    // Utility to compare images
    private func compareImages(_ image1: CGImage, _ image2: CGImage) -> Float {
        guard image1.width == image2.width, image1.height == image2.height else {
            print("Image dimensions do not match.")
            return 0.0 // Completely disimilar
        }

        let width = image1.width
        let height = image1.height
        let bytesPerPixel = 8 // 16-bit float per channel (4  channels: RGBA)
        let alignment = 256
        let unalignedBytesPerRow = width * bytesPerPixel
        let bytesPerRow = ((unalignedBytesPerRow + alignment - 1) / alignment) * alignment // align to 256 bytes
        let dataSize = bytesPerRow * height

        // Create raw data buffers
        let rawData1 = UnsafeMutableRawPointer.allocate(byteCount: dataSize, alignment: 1)
        let rawData2 = UnsafeMutableRawPointer.allocate(byteCount: dataSize, alignment: 1)

        defer {
            rawData1.deallocate()
            rawData2.deallocate()
        }

        // Copy pixel data from CGImages
        let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
        let bitmapInfo: CGBitmapInfo = [
            .floatComponents,
            CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            CGBitmapInfo(rawValue: CGImageByteOrderInfo.order16Little.rawValue),
        ]

        guard let context1 = CGContext(
            data: rawData1,
            width: width,
            height: height,
            bitsPerComponent: 16, // 16 bits per channel
            bytesPerRow: unalignedBytesPerRow, // Use unaligned row size
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ), let context2 = CGContext(
            data: rawData2,
            width: width,
            height: height,
            bitsPerComponent: 16, // 16 bits per channel
            bytesPerRow: unalignedBytesPerRow, // Use unaligned row size
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            print("Failed to create bitmap contexts.")
            return 0.0
        }

        context1.draw(image1, in: CGRect(x: 0, y: 0, width: width, height: height))
        context2.draw(image2, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Compare pixel data
        let pixelData1 = rawData1.bindMemory(to: Float16.self, capacity: dataSize / 2)
        let pixelData2 = rawData2.bindMemory(to: Float16.self, capacity: dataSize / 2)

        var totalDifference: Float = 0.0
        let pixelCount = width * height * 4 // 4 channels (RGBA)
        for i in 0 ..< pixelCount {
            totalDifference += abs(Float(pixelData1[i]) - Float(pixelData2[i]))
        }

        // Normalize and calculate similarity
        let averageDifference = totalDifference / Float(pixelCount)
        print("Avg Difference : \(averageDifference)")
        return averageDifference
    }

    // Matrix Comparison
    private func compareMatrices(_ m1: simd_float4x4, _ m2: simd_float4x4, tolerance: Float = 1e-5) -> Bool {
        for row in 0 ..< 4 {
            for col in 0 ..< 4 {
                if abs(m1[row][col] - m2[row][col]) > tolerance {
                    return false
                }
            }
        }
        return true
    }

    private func saveTextureAsReferenceImage(texture: MTLTexture, fileName: String) {
        if let cgImage = textureToCGImage(texture: texture) {
            saveCGImageToDisk(cgImage, fileName: fileName)
        } else {
            print("Failed to convert texture to CGImage")
        }
    }

    private func initializeAssets() {
        let player: EntityID = createEntity()
        setEntityMesh(entityId: player, filename: "scifihelmet", withExtension: "usdc")

        let sunEntity: EntityID = createEntity()

        // Create the directional light instance
        let sun = DirectionalLight()

        // Add the light to the lighting system
        lightingSystem.addDirectionalLight(entityID: sunEntity, light: sun)
    }
}
