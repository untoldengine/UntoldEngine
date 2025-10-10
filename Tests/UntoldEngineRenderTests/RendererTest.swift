//
//  RendererTest.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.

import CShaderTypes
import simd
import UniformTypeIdentifiers
@testable import UntoldEngine
import XCTest

final class RendererTests: XCTestCase {
    var renderer: UntoldRenderer!
    var window: NSWindow!
    let saveToDisk: Bool = true // set to true to save ref, rendered and diff images to the download folder: Download/UntoldEngineRenderingTest
    let timeoutFactor: Float = 5.0
    let windowWidth = 1920
    let windowHeight = 1080

    // Set up a headless renderer.
    override func setUp() {
        super.setUp()
        ambientIntensity = 0.4

        // Create the renderer as usual
        guard let renderer = UntoldRenderer.create() else {
            XCTFail("Failed to initialize the renderer.")
            return
        }
        self.renderer = renderer

        // Pick a canonical test size (1× pixels, same references/CI)
        let size = CGSize(width: windowWidth, height: windowHeight)

        // DO NOT create/attach a window (no Retina/backingScale involved)
        // Just configure the MTKView directly.
        renderer.metalView.autoResizeDrawable = false
        renderer.metalView.drawableSize = size // pixels (locks 1×)
        (renderer.metalView.layer as? CAMetalLayer)?.contentsScale = 1.0 // belt-and-suspenders
        renderer.metalView.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight) // bounds in points

        renderer.mtkView(renderer.metalView, drawableSizeWillChange: size)

        let aspect = Float(windowWidth) / Float(windowHeight)
        renderInfo.perspectiveSpace = matrixPerspectiveRightHand(
            fovyRadians: degreesToRadians(degrees: fov),
            aspectRatio: aspect, nearZ: near, farZ: far
        )

        renderInfo.viewPort = simd_float2(Float(windowWidth), Float(windowHeight))

        initializeAssets()

        setVisibleEntities()
    }

    override func tearDown() {
        super.tearDown()
    }

    // Temp solution until I figure out how to get culling working inside this test routine
    func setVisibleEntities() {
        let transformId = getComponentId(for: WorldTransformComponent.self)
        let renderId = getComponentId(for: RenderComponent.self)
        let entities = queryEntitiesWithComponentIds([transformId, renderId], in: scene)

        for entity in entities {
            visibleEntityIds.append(entity)
        }
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

     //                self.testGenerateRenderTarget(
     //                    targetName: "DepthTarget",
     //                    texture: renderInfo.offscreenRenderPassDescriptor.depthAttachment.texture!,
     //                    isDepthTexture: true
     //                )

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

        _ = saveResultToDisk(image, "\(targetName)Reference")
    }

    private func psnrTest(targetName: String, texture: MTLTexture, isDepthTexture: Bool = false) {
        // 0) Texture → CGImage
        let renderImage: CGImage? = isDepthTexture
            ? depthTextureToCGImage(texture: texture)
            : textureToCGImage(texture: texture)

        guard let finalImage = renderImage else {
            XCTFail("\(targetName): Renderer should produce an output image")
            return
        }

        // 1) Env & paths
        let env = ProcessInfo.processInfo.environment
        let runStamp = String(Int(Date().timeIntervalSince1970))
        let baseTemp = FileManager.default.temporaryDirectory.appendingPathComponent(runStamp, isDirectory: true)
        let isCI = (env["CI"] == "true") || (env["GITHUB_ACTIONS"] == "true")
        let keepFlag = (env["UNTOLD_KEEP_ARTIFACTS"] == "1")
        let pythonCmd = env["UNTOLD_PYTHON"] ?? "python3"
        let threshold: String = env["UNTOLD_PSNR_THRESHOLD"] ?? "35.0"

        do { try FileManager.default.createDirectory(at: baseTemp, withIntermediateDirectories: true) }
        catch { XCTFail("Failed to create temp dir: \(error)"); return }

        // 2) Save test image
        guard let testImageURL = saveResultToDisk(finalImage, named: "\(targetName)Test", in: baseTemp) else {
            XCTFail("Failed to save test image for \(targetName)")
            return
        }

        // 3) Locate script + reference
        guard let scriptURL = Bundle.module.url(forResource: "compare_psnr", withExtension: "py") else {
            XCTFail("compare_psnr.py not found in test bundle")
            return
        }
        guard let referenceURL = Bundle.module.url(forResource: "\(targetName)Reference", withExtension: "png") else {
            XCTFail("Reference image for \(targetName) not found in test bundle")
            return
        }

        // 4) Run python script
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [pythonCmd, scriptURL.path, referenceURL.path, testImageURL.path, "--threshold", threshold]
        process.currentDirectoryURL = scriptURL.deletingLastPathComponent()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "No output"

            // 5) Attach artifacts to XCTest
            if FileManager.default.fileExists(atPath: testImageURL.path) {
                let testAttachment = XCTAttachment(contentsOfFile: testImageURL)
                testAttachment.name = "\(targetName)Test.png"
                testAttachment.lifetime = (process.terminationStatus == 0) ? .deleteOnSuccess : .keepAlways
                add(testAttachment)
            }

            if FileManager.default.fileExists(atPath: referenceURL.path) {
                let refAttachment = XCTAttachment(contentsOfFile: referenceURL)
                refAttachment.name = "\(targetName)Reference.png"
                refAttachment.lifetime = (process.terminationStatus == 0) ? .deleteOnSuccess : .keepAlways
                add(refAttachment)
            }

            // 6) Optional local copies to ~/Downloads (skip on CI unless forced)
            if keepFlag || process.terminationStatus != 0, !isCI {
                if let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                    let keepDir = downloads
                        .appendingPathComponent("UntoldEngineRenderingTest", isDirectory: true)
                        .appendingPathComponent("\(targetName)-\(runStamp)", isDirectory: true)
                    try? FileManager.default.createDirectory(at: keepDir, withIntermediateDirectories: true)

                    let dstTest = keepDir.appendingPathComponent(testImageURL.lastPathComponent)
                    let dstRef = keepDir.appendingPathComponent(referenceURL.lastPathComponent)
                    try? FileManager.default.removeItem(at: dstTest)
                    try? FileManager.default.removeItem(at: dstRef)
                    try? FileManager.default.copyItem(at: testImageURL, to: dstTest)
                    try? FileManager.default.copyItem(at: referenceURL, to: dstRef)
                    print("🧪 Artifacts kept at: \(keepDir.path)")
                }
            } else {
                print("🧪 Temp artifacts at: \(baseTemp.path)")
            }

            // 7) Assert on script exit code
            if process.terminationStatus != 0 {
                XCTFail("\(targetName): ❌ PSNR test failed. Output: \(output)")
            } else {
                // Optional nice log (if your script prints PSNR=xx.xx)
                print("✅ \(targetName): \(output)")
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

    @discardableResult
    private func saveResultToDisk(_ image: CGImage,
                                  named imageName: String,
                                  in baseDirectory: URL) -> URL?
    {
        guard saveToDisk else { return nil }

        let folderURL = baseDirectory.appendingPathComponent("UntoldEngineRenderingTest", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Failed to create directory \(folderURL.path): \(error)")
            return nil
        }

        // ensure .png
        let fileURL = folderURL.appendingPathComponent(
            imageName.hasSuffix(".png") ? imageName : "\(imageName).png"
        )

        // write PNG
        guard let dest = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            print("Failed to create image destination for \(fileURL.path)")
            return nil
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            print("Failed to write image to \(fileURL.path)")
            return nil
        }

        print("Saved image to \(fileURL.path)")
        return fileURL
    }

    @discardableResult
    private func saveResultToDisk(_ image: CGImage, _ imageName: String) -> URL? {
        guard let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            print("Failed to locate Downloads directory.")
            return nil
        }
        return saveResultToDisk(image, named: imageName, in: downloads)
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
