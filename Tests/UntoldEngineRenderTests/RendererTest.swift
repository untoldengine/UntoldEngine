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

final class RendererTests: BaseRenderSetup {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testRendererInitialization() {
        XCTAssertNotNil(renderer, "❌ Renderer should be inialized.")
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
        XCTAssertTrue(compareMatrices(actualProjectionMatrix, expectedProjectionMatrix), "❌ Projection matrix is incorrect.")

        // Check viewport dimensions
        let expectedViewport = simd_make_float2(Float(windowWidth), Float(windowHeight))
        XCTAssertEqual(renderInfo.viewPort, expectedViewport, "❌ Viewport dimensions are incorrect.")
    }

    /* Uncomment to generate reference images*/
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
                 targetName: "TransparencyTarget",
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

    func testTransparencyTarget() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "Transparency target test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.psnrTest(
                targetName: "TransparencyTarget",
                texture: renderInfo.deferredRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
    }

    func testFinalColorPipelinesInitialized() {
        guard let lookPipeline = PipelineManager.shared.renderPipelinesByType[.look] else {
            XCTFail("Look pipeline should be initialized")
            return
        }
        guard let outputPipeline = PipelineManager.shared.renderPipelinesByType[.outputTransform] else {
            XCTFail("Output transform pipeline should be initialized")
            return
        }

        XCTAssertTrue(lookPipeline.success, "Look pipeline should compile successfully")
        XCTAssertTrue(outputPipeline.success, "Output transform pipeline should compile successfully")
    }

    func testFinalColorWorkingTexturesConfigured() {
        let workingFormats = renderInfo.colorPipeline.working

        XCTAssertNotNil(textureResources.sceneCompositeTexture, "Scene composite texture should exist")
        XCTAssertNotNil(textureResources.lookTexture, "Look output texture should exist")
        XCTAssertEqual(textureResources.sceneCompositeTexture?.pixelFormat, workingFormats.sceneComposite,
                       "Scene composite texture should use the configured working sceneComposite format")
        XCTAssertEqual(textureResources.lookTexture?.pixelFormat, workingFormats.lookOutput,
                       "Look output texture should use the configured working lookOutput format")

        let descriptorTexture = renderInfo.sceneCompositeRenderPassDescriptor?.colorAttachments[0].texture
        XCTAssertNotNil(descriptorTexture, "Scene composite pass should have a color attachment texture")
        XCTAssertTrue(descriptorTexture === textureResources.sceneCompositeTexture,
                      "Scene composite pass should render into sceneCompositeTexture")

        XCTAssertEqual(renderInfo.colorPipeline.present.pixelFormat, renderInfo.presentColorPixelFormat,
                       "Present config pixel format should mirror the renderer present format")
        let expectedEncoding: OutputEncodingMode = renderInfo.presentColorPixelFormat.isSRGBFormat ? .hardwareSRGB : .manualSRGBOETF
        XCTAssertEqual(renderInfo.colorPipeline.present.encodingMode, expectedEncoding,
                       "Present encoding mode should match the present pixel format policy")
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

    func testDefaultMeshCreation() {
        let mesh = Mesh.makeDefaultMesh()

        XCTAssertGreaterThan(mesh[0].metalKitMesh.vertexCount, 0)
        XCTAssertGreaterThan(mesh[0].metalKitMesh.submeshes.count, 0)
        // verify attribute layout index 0 = position, 1 = uv, etc.
        let vb = mesh[0].metalKitMesh.vertexBuffers.first!
        XCTAssertGreaterThan(vb.length, 0)
    }

    func testDefaultTextureHasMipsAndSRGB() {
        let loader = TextureLoader(device: renderInfo.device)
        let tex = loader.defaultTexture()
        XCTAssertEqual(tex.width, 64)
        XCTAssertEqual(tex.height, 64)
        XCTAssertGreaterThan(tex.mipmapLevelCount, 1, "Checker texture should have mipmaps")
        XCTAssertEqual(tex.pixelFormat, .rgba8Unorm_srgb)
    }
}
