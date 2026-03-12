//
//  UntoldEngineAR.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#if os(iOS)
    #if canImport(ARKit)
        import ARKit
    #endif
    import CShaderTypes
    import Foundation
    import Metal
    import MetalKit
    import UntoldEngine

    public enum UntoldARMode {
        case worldTracking
        case faceTracking
        case imageTracking
    }

    enum ARSystemState { case paused, running, stopped }

    /// Vertex data for an image plane
    let kImagePlaneVertexData: [Float] = [
        -1.0, -1.0, 0.0, 1.0,
        1.0, -1.0, 1.0, 1.0,
        -1.0, 1.0, 0.0, 0.0,
        1.0, 1.0, 1.0, 0.0,
    ]

    @MainActor
    public final class UntoldEngineAR {
        private var renderer: UntoldRenderer?

        #if canImport(ARKit)
            private var arSession = ARSession()
        #else
            private let arSession: Any? = nil
        #endif

        /// Initialize to nil so the initializer does not need to assign it.
        private let arFrame: ARFrame? = nil
        /// Provide a sensible default; can be changed later as needed.
        private var arMode: UntoldARMode = .worldTracking

        // AR Camera feed textures
        public var capturedImageTextureY: CVMetalTexture?
        public var capturedImageTextureCbCr: CVMetalTexture?

        /// Captured image texture cache
        var capturedImageTextureCache: CVMetalTextureCache!

        var imagePlaneVertexBuffer: MTLBuffer!
        var capturedImagePipelineState: MTLRenderPipelineState!
        var capturedImageDepthState: MTLDepthStencilState!

        var viewportSizeDidChange: Bool = false

        var currentARCamera: simd_float4x4 = .init(1.0)
        var currentARProjection: simd_float4x4 = .init(1.0)

        public init?(session: ARSession, device: MTLDevice, view: MTKView) {
            arSession = session

            guard let untoldrenderer = UntoldRenderer.createAR(configuration: nil, device: device, view: view) else {
                print("Failed to initialize the renderer")
                return nil
            }

            renderer = untoldrenderer

            initializeCapturedImagePipeline()
        }

        public func setupCallbacks(
            gameUpdate: @escaping (_ deltaTime: Float) -> Void,
            handleInput: @escaping () -> Void
        ) {
            renderer?.setupCallbacks(gameUpdate: gameUpdate, handleInput: handleInput)
        }

        public func drawRectResized(size: CGSize) {
            renderInfo.viewPort = simd_float2(Float(size.width), Float(size.height))
            viewportSizeDidChange = true
            renderer?.initSizeableResources()
        }

        public func draw(in view: MTKView) {
            guard let renderer else {
                return
            }

            guard let currentFrame = arSession.currentFrame else {
                return
            }

            // Wait for available command buffer slot to prevent unbounded memory growth
            commandBufferSemaphore.wait()

            // Create a new command buffer for each renderpass to the current drawable
            guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
                // Failed to create command buffer - release semaphore
                commandBufferSemaphore.signal()
                return
            }

            commandBuffer.label = "AR Command Buffer"

            // Retain our CVMetalTextures for the duration of the rendering cycle. The MTLTextures
            //   we use from the CVMetalTextures are not valid unless their parent CVMetalTextures
            //   are retained. Since we may release our CVMetalTexture ivars during the rendering
            //   cycle, we must retain them separately here.
            var textures = [capturedImageTextureY, capturedImageTextureCbCr]
            commandBuffer.addCompletedHandler { _ in
                // Signal that this command buffer slot is now available
                commandBufferSemaphore.signal()
                textures.removeAll()
            }

            currentARCamera = currentFrame.camera.viewMatrix(for: .landscapeRight)
            let vpSize = CGSize(width: CGFloat(renderInfo.viewPort.x), height: CGFloat(renderInfo.viewPort.y))
            currentARProjection = currentFrame.camera.projectionMatrix(for: .landscapeRight, viewportSize: vpSize, zNear: 0.001, zFar: 1000)

            EngineProfiler.shared.beginScope(.renderPrep)
            updateARStates(currentFrame: currentFrame)
            EngineProfiler.shared.endScope(.renderPrep)

            renderer.updateXR()

            if let renderPassDescriptor = view.currentRenderPassDescriptor {
                renderInfo.renderPassDescriptor = renderPassDescriptor

                EngineProfiler.shared.beginScope(.encode)
                drawCapturedImage(commandBuffer: commandBuffer)

                renderer.renderXR(commandBuffer: commandBuffer,
                                  passDescriptor: renderPassDescriptor,
                                  viewMatrix: currentARCamera,
                                  projectionMatrix: currentARProjection,
                                  eyeIndex: 0)
                EngineProfiler.shared.endScope(.encode)

                // Schedule a present once the framebuffer is complete using the current drawable
                if let drawable = view.currentDrawable {
                    commandBuffer.present(drawable)
                }
            }

            EngineProfiler.shared.attach(to: commandBuffer, label: "ARFrame")

            // Finalize rendering here & push the command buffer to the GPU
            commandBuffer.commit()
        }

        func updateARStates(currentFrame: ARFrame) {
            // updateAnchors(frame: currentFrame)
            updateCapturedImageTextures(frame: currentFrame)

            if viewportSizeDidChange {
                viewportSizeDidChange = false

                updateImagePlane(frame: currentFrame)
            }
        }

        func initializeCapturedImagePipeline() {
            // Create a vertex buffer with our image plane vertex data.
            let imagePlaneVertexDataCount = kImagePlaneVertexData.count * MemoryLayout<Float>.size
            imagePlaneVertexBuffer = renderInfo.device.makeBuffer(bytes: kImagePlaneVertexData, length: imagePlaneVertexDataCount, options: [])
            imagePlaneVertexBuffer.label = "ImagePlaneVertexBuffer"

            let capturedImageVertexFunction = renderInfo.library.makeFunction(name: "capturedImageVertexTransform")!
            let capturedImageFragmentFunction = renderInfo.library.makeFunction(name: "capturedImageFragmentShader")!

            // Create a vertex descriptor for our image plane vertex buffer
            let imagePlaneVertexDescriptor = MTLVertexDescriptor()

            // Positions.
            imagePlaneVertexDescriptor.attributes[Int(kVertexAttributePosition.rawValue)].format = .float2
            imagePlaneVertexDescriptor.attributes[Int(kVertexAttributePosition.rawValue)].offset = 0
            imagePlaneVertexDescriptor.attributes[Int(kVertexAttributePosition.rawValue)].bufferIndex = Int(imagePlaneARPositions.rawValue)

            // Texture coordinates.
            imagePlaneVertexDescriptor.attributes[Int(kVertexAttributeTexcoord.rawValue)].format = .float2
            imagePlaneVertexDescriptor.attributes[Int(kVertexAttributeTexcoord.rawValue)].offset = 8
            imagePlaneVertexDescriptor.attributes[Int(kVertexAttributeTexcoord.rawValue)].bufferIndex = Int(imagePlaneARPositions.rawValue)

            // Buffer Layout
            imagePlaneVertexDescriptor.layouts[Int(imagePlaneARPositions.rawValue)].stride = 16
            imagePlaneVertexDescriptor.layouts[Int(imagePlaneARPositions.rawValue)].stepRate = 1
            imagePlaneVertexDescriptor.layouts[Int(imagePlaneARPositions.rawValue)].stepFunction = .perVertex

            // Create a pipeline state for rendering the captured image
            let capturedImagePipelineStateDescriptor = MTLRenderPipelineDescriptor()
            capturedImagePipelineStateDescriptor.label = "MyCapturedImagePipeline"
            capturedImagePipelineStateDescriptor.rasterSampleCount = 1
            capturedImagePipelineStateDescriptor.vertexFunction = capturedImageVertexFunction
            capturedImagePipelineStateDescriptor.fragmentFunction = capturedImageFragmentFunction
            capturedImagePipelineStateDescriptor.vertexDescriptor = imagePlaneVertexDescriptor
            capturedImagePipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
            capturedImagePipelineStateDescriptor.depthAttachmentPixelFormat = .depth32Float
            // capturedImagePipelineStateDescriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8

            do {
                try capturedImagePipelineState = renderInfo.device.makeRenderPipelineState(descriptor: capturedImagePipelineStateDescriptor)
            } catch {
                print("Failed to created captured image pipeline state, error \(error)")
            }

            let capturedImageDepthStateDescriptor = MTLDepthStencilDescriptor()
            capturedImageDepthStateDescriptor.depthCompareFunction = .always
            capturedImageDepthStateDescriptor.isDepthWriteEnabled = false
            capturedImageDepthState = renderInfo.device.makeDepthStencilState(descriptor: capturedImageDepthStateDescriptor)

            // Create captured image texture cache
            var textureCache: CVMetalTextureCache?
            CVMetalTextureCacheCreate(nil, nil, renderInfo.device, nil, &textureCache)
            capturedImageTextureCache = textureCache
        }

        func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
            let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
            let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)

            var texture: CVMetalTexture? = nil
            let status = CVMetalTextureCacheCreateTextureFromImage(nil, capturedImageTextureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)

            if status != kCVReturnSuccess {
                texture = nil
            }

            return texture
        }

        func updateCapturedImageTextures(frame: ARFrame) {
            // Create two textures (Y and CbCr) from the provided frame's captured image
            let pixelBuffer = frame.capturedImage

            if CVPixelBufferGetPlaneCount(pixelBuffer) < 2 {
                return
            }

            capturedImageTextureY = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .r8Unorm, planeIndex: 0)
            capturedImageTextureCbCr = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .rg8Unorm, planeIndex: 1)
        }

        func updateImagePlane(frame: ARFrame) {
            // Update the texture coordinates of our image plane to aspect fill the viewport
            let vpSize = CGSize(width: CGFloat(renderInfo.viewPort.x), height: CGFloat(renderInfo.viewPort.y))
            let displayToCameraTransform = frame.displayTransform(for: .landscapeRight, viewportSize: vpSize).inverted()

            let vertexData = imagePlaneVertexBuffer.contents().assumingMemoryBound(to: Float.self)
            for index in 0 ... 3 {
                let textureCoordIndex = 4 * index + 2
                let textureCoord = CGPoint(x: CGFloat(kImagePlaneVertexData[textureCoordIndex]), y: CGFloat(kImagePlaneVertexData[textureCoordIndex + 1]))
                let transformedCoord = textureCoord.applying(displayToCameraTransform)
                vertexData[textureCoordIndex] = Float(transformedCoord.x)
                vertexData[textureCoordIndex + 1] = Float(transformedCoord.y)
            }
        }

        func drawCapturedImage(commandBuffer: MTLCommandBuffer) {
            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderInfo.environmentRenderPassDescriptor)
            else {
                handleError(.renderPassCreationFailed, "AR Pass")
                return
            }

            guard let textureY = capturedImageTextureY, let textureCbCr = capturedImageTextureCbCr else {
                return
            }

            // Push a debug group allowing us to identify render commands in the GPU Frame Capture tool
            renderEncoder.pushDebugGroup("DrawCapturedImage")

            // Set render command encoder state
            renderEncoder.setCullMode(.none)
            renderEncoder.setRenderPipelineState(capturedImagePipelineState)
            renderEncoder.setDepthStencilState(capturedImageDepthState)

            // Set mesh's vertex buffers
            renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: Int(imagePlaneARPositions.rawValue))

            // Set any textures read/sampled from our render pipeline
            renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureY), index: Int(textureARIndexY.rawValue))
            renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureCbCr), index: Int(textureARIndexCbCr.rawValue))

            // Draw each submesh of our mesh
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

            renderEncoder.popDebugGroup()

            renderEncoder.endEncoding()
        }
    }

#endif
