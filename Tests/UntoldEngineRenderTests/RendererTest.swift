//
//  RendererTest.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.

import CShaderTypes
import simd
@testable import UntoldEngine
import XCTest

final class RendererTests: XCTestCase {
    var renderer: UntoldRenderer!
    var window: NSWindow!
    let saveToDisk: Bool = true // set to true to save ref, rendered and diff images to the download folder: Download/UntoldEngineRenderingTest
    let timeoutFactor: Float = 5.0
    let windowWidth = 1920
    let windowHeight = 1080

    override func setUp() {
        super.setUp()
        ambientIntensity = 0.4

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)

        window.title = "Test Window"

        // Initialize the renderer
        guard let renderer = UntoldRenderer.create() else {
            XCTFail("Failed to initialize the renderer.")
            return
        }

        window.contentView = renderer.metalView

        self.renderer = renderer

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
        let far: Float = far
        let near: Float = near
        let fov: Float = fov

        // Aspect ratio
        let aspect = Float(windowWidth) / Float(windowHeight)

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
        let expectedViewport = simd_make_float2(Float(windowWidth), Float(windowHeight))
        XCTAssertEqual(renderInfo.viewPort, expectedViewport, "Viewport dimensions are incorrect.")
    }

    /*
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
                    targetName: "SpecularIBL",
                    texture: textureResources.specularMap!
                )

                self.testGenerateRenderTarget(
                    targetName: "BRDFIBL",
                    texture: textureResources.iblBRDFMap!
                )

                self.testGenerateRenderTarget(
                    targetName: "DepthTarget",
                    texture: renderInfo.offscreenRenderPassDescriptor.depthAttachment.texture!,
                    isDepthTexture: true
                )

                self.testGenerateRenderTarget(
                   targetName: "LightPassColor",
                   texture: renderInfo.deferredRenderPassDescriptor.colorAttachments[0].texture!
                )

                self.testGenerateRenderTarget(
                    targetName: "CompositeColorTarget",
                    texture: renderInfo.renderPassDescriptor.colorAttachments[0].texture!
                )

                expectation.fulfill()
            }

            // Wait for the execution
            wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
        }
     */
    func testColorTarget() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "ColorTarget test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.psnrTest(
                targetName: "ColorTarget",
                texture: renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
    }

    func testNormalTarget() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "NormalTarget test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.psnrTest(
                targetName: "NormalTarget",
                texture: renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)].texture!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
    }

    func testPositionTarget() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "PositionTarget test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.psnrTest(
                targetName: "PositionTarget",
                texture: renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)].texture!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
    }

    func testLightPassColorTarget() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "Light Pass Color test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.psnrTest(
                targetName: "LightPassColor",
                texture: renderInfo.deferredRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
    }

    func testIrradianceIBL() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "IrradianceIBL test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.psnrTest(
                targetName: "IrradianceIBL",
                texture: textureResources.irradianceMap!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
    }

    func testSpecularIBL() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "SpecularIBL test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.psnrTest(
                targetName: "SpecularIBL",
                texture: textureResources.specularMap!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
    }

    func testBRDFIBL() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "BRDFIBL test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.psnrTest(
                targetName: "BRDFIBL",
                texture: textureResources.iblBRDFMap!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
    }

//    func testCompositeColorTarget() {
//        XCTAssertNotNil(renderer, "Renderer should be initialized")
//        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")
//
//        renderer.draw(in: renderer.metalView)
//
//        let expectation = XCTestExpectation(description: "CompositeColorTarget test")
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//            self.psnrTest(
//                targetName: "CompositeColorTarget",
//                texture: renderInfo.renderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture!
//            )
//            expectation.fulfill()
//        }
//
//        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
//    }
    /*
     func testDepthTarget() {
         XCTAssertNotNil(renderer, "Renderer should be initialized")
         XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

         renderer.draw(in: renderer.metalView)

         let expectation = XCTestExpectation(description: "DepthTarget test")

         DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
             self.psnrTest(
                 targetName: "DepthTarget",
                 texture: renderInfo.offscreenRenderPassDescriptor.depthAttachment.texture!,
                 isDepthTexture: true
             )
             expectation.fulfill()
         }

         wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
     }
     */
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

    private func psnrTest(targetName: String, texture: MTLTexture, isDepthTexture: Bool = false) {
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

        saveResultToDisk(finalImage, "\(targetName)Test")

        guard let desktopDirectory = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            print("Failed to locate Desktop directory.")
            return
        }

        let pythonPath = desktopDirectory
            .appendingPathComponent("UntoldEngineTest")
            .appendingPathComponent("bin")
            .appendingPathComponent("python3")

        let scriptPath = desktopDirectory
            .appendingPathComponent("UntoldEngineStudio")
            .appendingPathComponent("ImageComparison")
            .appendingPathComponent("compare_psnr.py")

        let referencePath = desktopDirectory
            .appendingPathComponent("UntoldEngineStudio")
            .appendingPathComponent("UntoldEngine")
            .appendingPathComponent("Sources")
            .appendingPathComponent("UntoldEngine")
            .appendingPathComponent("Resources")
            .appendingPathComponent("ReferenceImages")
            .appendingPathComponent("\(targetName)Reference.png")

        guard let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            print("Failed to locate Downloads directory.")
            return
        }

        let testPath = downloadsDirectory
            .appendingPathComponent("UntoldEngineRenderingTest")
            .appendingPathComponent("\(targetName)Test.png")

        let process = Process()
        process.executableURL = pythonPath
        process.arguments = [scriptPath.path, referencePath.path, testPath.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "No output"

            if process.terminationStatus == 0 {
            } else {
                XCTFail("\(targetName): ❌ PSNR test failed. Value: \(output)")
            }

        } catch {
            XCTFail("\(targetName): ❌ Failed to run PSNR comparison – \(error)")
        }
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
        cameraLookAt(entityId: findGameCamera(), eye: simd_float3(0.0, 3.0, 7.0), target: simd_float3(0.0, 0.0, 0.0), up: simd_float3(0.0, 1.0, 0.0))

        let helmet: EntityID = createEntity()

        setEntityMesh(entityId: helmet, filename: "whitehelmet", withExtension: "usdc")

        translateTo(entityId: helmet, position: simd_float3(0.0, 1.5, 0.0))

        let plane: EntityID = createEntity()

        setEntityMesh(entityId: plane, filename: "plane", withExtension: "usdc")

        let sunEntity: EntityID = createEntity()

        createDirLight(entityId: sunEntity)

        let pointLight = createEntity()
        createPointLight(entityId: pointLight)

        translateTo(entityId: pointLight, position: simd_float3(2.0, 1.0, 0.0))

        let spotLight = createEntity()
        createSpotLight(entityId: spotLight)

        translateTo(entityId: spotLight, position: simd_float3(-3.0, 1.0, 0.0))

        renderEnvironment = true
    }
}
