//
//  RendererTest.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 12/30/24.

import CShaderTypes
import simd
@testable import UntoldEngine
import XCTest

final class RendererTests: XCTestCase {
    var renderer: UntoldRenderer!
    var window: NSWindow!
    let saveToDisk: Bool = false // set to true to save ref, rendered and diff images to the download folder: Download/UntoldEngineRenderingTest

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

    func testGenerateReferenceImages() {
        // Ensure renderer and metalview are properly initialized
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        // Manually trigger the draw call
        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "Render graph execution delay")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // generate different render targets

            self.testGenerateRenderTarget(
                targetName: "ColorTarget",
                texture: renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture!
            )

            self.testGenerateRenderTarget(
                targetName: "NormalTarget",
                texture: renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)].texture!
            )

            self.testGenerateRenderTarget(
                targetName: "PositionTarget",
                texture: renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)].texture!
            )

            self.testGenerateRenderTarget(
                targetName: "IrradianceIBL",
                texture: textureResources.irradianceMap!
            )

            self.testGenerateRenderTarget(
                targetName: "IrradianceIBL",
                texture: textureResources.irradianceMap!
            )

            self.testGenerateRenderTarget(
                targetName: "SpecularIBL",
                texture: textureResources.specularMap!
            )

            self.testGenerateRenderTarget(
                targetName: "BRDFIBL",
                texture: textureResources.iblBRDFMap!
            )

            self.testGenerateRenderTarget(
                targetName: "CompositeColorTarget",
                texture: renderInfo.renderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture!
            )

            self.testGenerateRenderTarget(
                targetName: "DepthTarget",
                texture: renderInfo.offscreenRenderPassDescriptor.depthAttachment.texture!,
                isDepthTexture: true
            )

            expectation.fulfill()
        }

        // Wait for the execution
        wait(for: [expectation], timeout: 2.0)
    }

    func testColorTarget() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "ColorTarget test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.testRenderTarget(
                targetName: "ColorTarget",
                texture: renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testNormalTarget() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "NormalTarget test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.testRenderTarget(
                targetName: "NormalTarget",
                texture: renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)].texture!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testPositionTarget() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "PositionTarget test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.testRenderTarget(
                targetName: "PositionTarget",
                texture: renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)].texture!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testIrradianceIBL() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "IrradianceIBL test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.testRenderTarget(
                targetName: "IrradianceIBL",
                texture: textureResources.irradianceMap!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSpecularIBL() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "SpecularIBL test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.testRenderTarget(
                targetName: "SpecularIBL",
                texture: textureResources.specularMap!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testBRDFIBL() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "BRDFIBL test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.testRenderTarget(
                targetName: "BRDFIBL",
                texture: textureResources.iblBRDFMap!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCompositeColorTarget() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "CompositeColorTarget test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.testRenderTarget(
                targetName: "CompositeColorTarget",
                texture: renderInfo.renderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testDepthTarget() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "DepthTarget test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.testRenderTarget(
                targetName: "DepthTarget",
                texture: renderInfo.offscreenRenderPassDescriptor.depthAttachment.texture!,
                isDepthTexture: true
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testRemoveEntityMesh() {
        // Create na entity
        let entityId = createEntity()

        setEntityMesh(entityId: entityId, filename: "hollandPlayer", withExtension: "usdc")

        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
            handleError(.noRenderComponent, entityId)
            return
        }

        guard let skeletonComponent = scene.get(component: SkeletonComponent.self, for: entityId) else {
            handleError(.noSkeletonComponent, entityId)
            return
        }

        removeEntityMesh(entityId: entityId)

        XCTAssertEqual(0, renderComponent.mesh.count, "Mesh should be empty")
        XCTAssertNil(skeletonComponent.skeleton, "Skeleton should be nil")
        XCTAssertNil(getMeshesForEntity(entityId: entityId), "Entity-Mesh map should be nil")

        // test if components have been removed
        XCTAssertFalse(hasComponent(entityId: entityId, componentType: RenderComponent.self))
        XCTAssertFalse(hasComponent(entityId: entityId, componentType: LocalTransformComponent.self))
        XCTAssertFalse(hasComponent(entityId: entityId, componentType: WorldTransformComponent.self))
        XCTAssertFalse(hasComponent(entityId: entityId, componentType: SkeletonComponent.self))
    }

    func testRemoveEntityAnimations() {
        // Create na entity
        let entityId = createEntity()

        setEntityMesh(entityId: entityId, filename: "hollandPlayer", withExtension: "usdc")
        setEntityAnimations(entityId: entityId, filename: "hollandIdleAnim", withExtension: "usdc", name: "idle")

        guard let animationComponent = scene.get(component: AnimationComponent.self, for: entityId) else {
            handleError(.noAnimationComponent, entityId)
            return
        }

        removeEntityMesh(entityId: entityId)
        removeEntityAnimations(entityId: entityId)

        XCTAssertNil(animationComponent.currentAnimation, "Current Animation should be Nil")
        XCTAssertEqual(animationComponent.animationClips.count, 0, "animation clips should be 0")

        // test if component have been removed
        XCTAssertFalse(hasComponent(entityId: entityId, componentType: AnimationComponent.self))
    }

    func testRemoveEntityKinetics() {
        // Create na entity
        let entityId = createEntity()

        setEntityMesh(entityId: entityId, filename: "hollandPlayer", withExtension: "usdc")
        setEntityKinetics(entityId: entityId)

        guard let kineticComponent = scene.get(component: KineticComponent.self, for: entityId) else {
            handleError(.noKineticComponent, entityId)
            return
        }

        removeEntityMesh(entityId: entityId)
        removeEntityKinetics(entityId: entityId)

        XCTAssertEqual(kineticComponent.forces.count, 0, "All forces should be removed")

        // test if components have been removed
        XCTAssertFalse(hasComponent(entityId: entityId, componentType: PhysicsComponents.self))
        XCTAssertFalse(hasComponent(entityId: entityId, componentType: KineticComponent.self))
    }

    private func testGenerateRenderTarget(targetName: String, texture: MTLTexture, isDepthTexture: Bool = false) {
        var renderImage: CGImage?

        if isDepthTexture {
            renderImage = depthTextureToCGImage(texture: texture)
        } else {
            renderImage = textureToCGImage(texture: texture)
        }

        // Get rendered image from the target
        guard let image = renderImage else {
            XCTFail("\(targetName): Renderer should produce an output image")
            return
        }

        saveResultToDisk(image, "\(targetName)Reference")
    }

    private func testRenderTarget(targetName: String, texture: MTLTexture, tolerance: Float = 1e-4, isDepthTexture: Bool = false) {
        // Load reference image
        guard let referenceImage = loadReferenceImage(refImageName: targetName + "Reference") else {
            XCTFail("\(targetName): Reference Image not generated")
            return
        }

        var renderImage: CGImage?

        if isDepthTexture {
            renderImage = depthTextureToCGImage(texture: texture)
        } else {
            renderImage = textureToCGImage(texture: texture)
        }

        // Get rendered image from the target
        guard let finalImage = renderImage else {
            XCTFail("\(targetName): Renderer should produce an output image")
            return
        }

        // Compare images
        let (averageDifference, diffImage) = compareImages(finalImage, referenceImage)

        guard let diffFinalImage = diffImage else {
            XCTFail("Unable to produce a final diff image")
            return
        }
        saveResultToDisk(finalImage, "\(targetName)Test")

        saveResultToDisk(referenceImage, "\(targetName)Reference")

        saveResultToDisk(diffFinalImage, "\(targetName)Diff")

        XCTAssert(averageDifference < tolerance, "Images are not similar enough. Difference: \(averageDifference)")
    }

    // Utility to load reference image
    private func loadReferenceImage(refImageName: String) -> CGImage? {
        // Load the reference CGImage from file
        guard let url = Bundle.module.url(forResource: refImageName, withExtension: "png") else {
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

    private func compareImages(_ image1: CGImage, _ image2: CGImage) -> (averageDifference: Float, diffImage: CGImage?) {
        guard image1.width == image2.width, image1.height == image2.height else {
            print("Image dimensions do not match.")
            return (0.0, nil) // Completely dissimilar, no difference image
        }

        let width = image1.width
        let height = image1.height
        let bytesPerPixel = 8 // 16-bit float per channel (4 channels: RGBA)
        let alignment = 256
        let unalignedBytesPerRow = width * bytesPerPixel
        let bytesPerRow = ((unalignedBytesPerRow + alignment - 1) / alignment) * alignment // Align to 256 bytes
        let dataSize = bytesPerRow * height

        // Allocate memory for the raw data
        let rawData1 = UnsafeMutableRawPointer.allocate(byteCount: dataSize, alignment: 1)
        let rawData2 = UnsafeMutableRawPointer.allocate(byteCount: dataSize, alignment: 1)
        var diffData = [UInt8](repeating: 0, count: width * height * 4) // Output as 8-bit for visualization

        defer {
            rawData1.deallocate()
            rawData2.deallocate()
        }

        let bitmapInfo: CGBitmapInfo = [
            .floatComponents,
            CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            CGBitmapInfo(rawValue: CGImageByteOrderInfo.order16Little.rawValue),
        ]

        // Create contexts for the input images
        guard let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB),
              let context1 = CGContext(
                  data: rawData1,
                  width: width,
                  height: height,
                  bitsPerComponent: 16,
                  bytesPerRow: unalignedBytesPerRow,
                  space: colorSpace,
                  bitmapInfo: bitmapInfo.rawValue
              ),
              let context2 = CGContext(
                  data: rawData2,
                  width: width,
                  height: height,
                  bitsPerComponent: 16,
                  bytesPerRow: unalignedBytesPerRow,
                  space: colorSpace,
                  bitmapInfo: bitmapInfo.rawValue
              )
        else {
            print("Failed to create contexts for input images.")
            return (0.0, nil)
        }

        // Draw the input images into the contexts
        context1.draw(image1, in: CGRect(x: 0, y: 0, width: width, height: height))
        context2.draw(image2, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Access pixel data for comparison
        let pixelData1 = rawData1.bindMemory(to: Float16.self, capacity: dataSize / 2)
        let pixelData2 = rawData2.bindMemory(to: Float16.self, capacity: dataSize / 2)

        // Calculate the absolute difference for each pixel and normalize to 8-bit for visualization
        var totalDifference: Float = 0.0
        let pixelCount = width * height * 4 // 4 channels (RGBA)

        for i in 0 ..< pixelCount {
            // Normalize Float16 values to the range [0, 1]
            let norm1 = Float(pixelData1[i]) / 65535.0
            let norm2 = Float(pixelData2[i]) / 65535.0
            let diff = abs(norm1 - norm2)
            totalDifference += diff

            // For visualization, scale normalized differences back to 8-bit range
            let scaledDiff = min(diff * 255.0, 255)
            diffData[i] = UInt8(scaledDiff)
        }

        // Normalize and calculate similarity
        let averageDifference = totalDifference / Float(pixelCount)

        // Create a new CGImage from the difference data
        guard let diffContext = CGContext(
            data: &diffData,
            width: width,
            height: height,
            bitsPerComponent: 8, // Output as 8-bit per channel for visualization
            bytesPerRow: width * 4, // 4 channels (RGBA)
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            print("Failed to create context for difference image.")
            return (averageDifference, nil)
        }

        let diffImage = diffContext.makeImage()
        return (averageDifference, diffImage)
    }

    private func compareDepthImages(_ image1: CGImage, _ image2: CGImage) -> (averageDifference: Float, diffImage: CGImage?) {
        guard image1.width == image2.width, image1.height == image2.height else {
            print("Image dimensions do not match.")
            return (0.0, nil) // Completely dissimilar, no difference image
        }

        let width = image1.width
        let height = image1.height
        let bytesPerPixel = 4 // 32-bit float per channel (1 channel: Grayscale)
        let alignment = 256
        let unalignedBytesPerRow = width * bytesPerPixel
        let bytesPerRow = ((unalignedBytesPerRow + alignment - 1) / alignment) * alignment
        let dataSize = bytesPerRow * height

        // Allocate memory for the raw data
        let rawData1 = UnsafeMutableRawPointer.allocate(byteCount: dataSize, alignment: 1)
        let rawData2 = UnsafeMutableRawPointer.allocate(byteCount: dataSize, alignment: 1)
        var diffData = [UInt8](repeating: 0, count: width * height) // Output as 8-bit grayscale for visualization

        defer {
            rawData1.deallocate()
            rawData2.deallocate()
        }

        let bitmapInfo: CGBitmapInfo = [
            .floatComponents,
            CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            CGBitmapInfo(rawValue: CGImageByteOrderInfo.order32Little.rawValue),
        ]

        // Create contexts for the input images
        guard let colorSpace = CGColorSpace(name: CGColorSpace.linearGray),
              let context1 = CGContext(
                  data: rawData1,
                  width: width,
                  height: height,
                  bitsPerComponent: 32, // 32 bits per channel
                  bytesPerRow: unalignedBytesPerRow,
                  space: colorSpace,
                  bitmapInfo: bitmapInfo.rawValue
              ),
              let context2 = CGContext(
                  data: rawData2,
                  width: width,
                  height: height,
                  bitsPerComponent: 32, // 32 bits per channel
                  bytesPerRow: unalignedBytesPerRow,
                  space: colorSpace,
                  bitmapInfo: bitmapInfo.rawValue
              )
        else {
            print("Failed to create contexts for input images.")
            return (0.0, nil)
        }

        // Draw the input images into the contexts
        context1.draw(image1, in: CGRect(x: 0, y: 0, width: width, height: height))
        context2.draw(image2, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Access pixel data for comparison
        let pixelData1 = rawData1.bindMemory(to: Float.self, capacity: width * height)
        let pixelData2 = rawData2.bindMemory(to: Float.self, capacity: width * height)

        // Calculate the absolute difference for each pixel and normalize for visualization
        var totalDifference: Float = 0.0
        let pixelCount = width * height

        for i in 0 ..< pixelCount {
            let depth1 = pixelData1[i]
            let depth2 = pixelData2[i]
            let diff = abs(depth1 - depth2)
            totalDifference += diff

            // Normalize depth difference to [0, 255] for visualization
            let normalizedDiff = UInt8(min(diff * 255.0, 255.0))
            diffData[i] = normalizedDiff
        }

        // Normalize the total difference
        let averageDifference = totalDifference / Float(pixelCount)

        // Create a grayscale CGImage from the difference data
        guard let diffContext = CGContext(
            data: &diffData,
            width: width,
            height: height,
            bitsPerComponent: 8, // 8 bits per channel for grayscale
            bytesPerRow: width, // 1 byte per pixel
            space: CGColorSpace(name: CGColorSpace.linearGray)!,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            print("Failed to create context for difference image.")
            return (averageDifference, nil)
        }

        let diffImage = diffContext.makeImage()
        return (averageDifference, diffImage)
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

    private func saveResultToDisk(_ image: CGImage, _ imageName: String) {
        if saveToDisk == false {
            return
        }
        // Get the user's Downloads directory
        guard let downloadDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            print("Failed to locate Downloads directory.")
            return
        }

        // Define the subdirectory path
        let folderName = "UntoldEngineRenderingTest"
        let folderURL = downloadDirectory.appendingPathComponent(folderName)

        // Create the folder if it doesn't exist
        do {
            if !FileManager.default.fileExists(atPath: folderURL.path) {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            }
        } catch {
            print("Failed to create directory \(folderURL.path): \(error)")
            return
        }

        // Save the image to the subdirectory
        saveCGImageToDisk(image, fileName: imageName, directory: folderURL)
    }

    private func initializeAssets() {
        camera.lookAt(
            eye: simd_float3(0.0, 0.5, 4.0), // Camera position
            target: simd_float3(0.0, 0.0, 0.0), // Look-at target
            up: simd_float3(0.0, 1.0, 0.0) // Up direction
        )

        let helmet: EntityID = createEntity()

        setEntityMesh(entityId: helmet, filename: "whitehelmet", withExtension: "usdc")

        let sunEntity: EntityID = createEntity()

        // Create the directional light instance
        let sun = DirectionalLight()

        // Add the light to the lighting system
        lightingSystem.addDirectionalLight(entityID: sunEntity, light: sun)

        renderEnvironment = true

        hdrURL = "potsdamer_platz_2k.hdr"
    }
}
