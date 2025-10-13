//
//  XRSystem_CompositorServices.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

#if os(visionOS)
    import CompositorServices
    import Foundation
    import Metal
    import UntoldEngine
    #if canImport(ARKit)
        import ARKit
    #endif

    enum XRLayerState { case paused, running, invalidated }

    public final class CompositorXRContext {
        public static let shared = CompositorXRContext()
        public var layerRenderer: LayerRenderer?
        private init() {}
    }

    @inline(__always)
    func layerRendererState() -> XRLayerState {
        guard let lr = CompositorXRContext.shared.layerRenderer else {
            return .invalidated
        }
        switch lr.state {
        case .paused: return .paused
        case .running: return .running
        case .invalidated: return .invalidated
        @unknown default: return .invalidated
        }
    }

    @inline(__always)
    func waitUntilRunning() {
        CompositorXRContext.shared.layerRenderer?.waitUntilRunning()
    }

    public final class CompositorXRSystem: XRSystem {
        private var renderer: UntoldRenderer?
        private var isRunning = false

        private let layerRenderer: LayerRenderer?

        #if canImport(ARKit)
            private let arSession = ARKitSession()
            private let worldTracking = WorldTrackingProvider()
        #else
            private let arSession: Any? = nil
            private let worldTracking: WorldTrackingProvider? = nil
        #endif
        
        private func startWorldTrackingIfNeeded(){
            guard worldTracking.state != .running else { return }
            Task {try? await arSession.run([worldTracking])}
        }

        public init?(layerRenderer: LayerRenderer, device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
            
            guard let device, let commandQueue = device.makeCommandQueue() else { return nil }
            
            self.layerRenderer = layerRenderer
            
            initUntoldXR(device: device, commandQueue: commandQueue, layerRenderer: layerRenderer)
        }
        
        public func initUntoldXR(device: MTLDevice, commandQueue: MTLCommandQueue, layerRenderer: LayerRenderer) {
            
            startWorldTrackingIfNeeded()
           
            let configuration = layerRenderer.configuration
            let layout = configuration.layout
            
            let colorPixelFormat = configuration.colorFormat
            let depthPixelFormat = configuration.depthFormat
            
            // **VERIFY THIS** Need to verify this. Couldn't find any info
            let viewPort:simd_float2 = simd_float2(1024,1024)
            
            guard let untoldrenderer = UntoldRenderer.createXR(configuration: nil, device: device, commandQueue: commandQueue, colorPixelFormat: colorPixelFormat, depthPixelFormat: depthPixelFormat, viewPort: viewPort) else{
                
                print("Failed to initialize the renderer")
                return
            }
            
            renderer = untoldrenderer
            
        }
        
        
        public func start() {
            isRunning = true
            
            if renderer == nil{
                return
            }
            
            let renderThread = Thread {
                self.runLoop()
            }
            renderThread.name = "Render Thread"
            renderThread.qualityOfService = .userInteractive
            renderThread.start()
        }

        public func stop() {}

        private func runLoop() {
            while isRunning {
                autoreleasepool {
                    switch layerRendererState() {
                    case .paused:
                        waitUntilRunning()

                    case .running:
                        // Call the per-frame function here
                        self.renderNewFrame()

                    case .invalidated:
                        isRunning = false
                    }
                }
            }
        }

        // Performs exactly one frame of rendering
        private func renderNewFrame() {
            // 1. Call queryNextFrame() to fetch the next frame to use for drawing
            guard let layerRenderer else { return }
            
            guard let frame = layerRenderer.queryNextFrame() else { return }

            // 2. Call predictTiming to get the predicted render deadlines for code
            guard let timing = frame.predictTiming() else { return }

            // 3. Call startUpdate() to mark the start of the update phase
            frame.startUpdate()

            // 4. Apply user interactions to the content and update any app-spefic data
            /*TODO*/
            
            // 5. Perform any rendering-related work that doesn't rely on the device anchor info
            guard let renderer else { return }
            renderer.updateXR()
            
            // 6. Call endupdate() to mark the end of the update phase
            frame.endUpdate()

            // 7. Call wait(until:tolerace) to puase your render loop until the optimal rendering time
            LayerRenderer.Clock().wait(until: timing.optimalInputTime, tolerance: .zero)

            // 8. Call startSubmission() to mark the start of submission phase
            frame.startSubmission()

            // 9. Encode any drawing commands that depend on the device position or orientation
            guard let drawable = frame.queryDrawable() else{
                frame.endSubmission()
                return
            }
    
            // 10. Fetch the predicted device anchor from ARKit using the frameTiming information, and
            // apply the anchor to your frame
            
            let actualTiming = drawable.frameTiming
            guard let anchor:DeviceAnchor = createPoseForTiming(at: actualTiming)else{
                print("Unable to create anchor pose for timing")
                return
            }
            
            drawable.deviceAnchor = anchor
            
            executeXRSystemPass(frame: frame, drawable: drawable)

            // 13. Call endSubmission to mark the end of the GPU submission
            frame.endSubmission()
        }
        
        func executeXRSystemPass(frame: LayerRenderer.Frame, drawable: LayerRenderer.Drawable){
           
            var commandBuffer: MTLCommandBuffer = renderInfo.commandQueue.makeCommandBuffer()!
            
            for (viewIndex, view) in drawable.views.enumerated() {
                let anchor = drawable.deviceAnchor
                guard let originFromDevice: simd_float4x4 = anchor?.originFromAnchorTransform else{
                    continue
                }
                
                let deviceFromView: simd_float4x4 = view.transform
                var cameraMatrix: simd_float4x4 = matrix_multiply(originFromDevice, deviceFromView)
               
                cameraMatrix = simd_inverse(cameraMatrix)
              
                var projection: simd_float4x4 = .init(1)
                
                if #available(visionOS 2.0, *) {
                    projection = drawable.computeProjection(convention: .rightUpBack, viewIndex: viewIndex)
                } else {
                    
                    let tangents: simd_float4 = view.tangents
                    let depthRange: simd_float2 = drawable.depthRange
                    
                    projection = makeProjectionMatrixFromTangents(tangents: tangents, depthRange: depthRange)
                }
                
                // create a pass descriptor
                let passDescriptor: MTLRenderPassDescriptor = MTLRenderPassDescriptor()
                passDescriptor.colorAttachments[0].texture = drawable.colorTextures[viewIndex]
                passDescriptor.colorAttachments[0].storeAction = .store
                passDescriptor.colorAttachments[0].loadAction = .clear
                passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
                
                passDescriptor.depthAttachment.texture = drawable.depthTextures[viewIndex]
                passDescriptor.depthAttachment.loadAction = .clear
                passDescriptor.depthAttachment.storeAction = .store
                passDescriptor.depthAttachment.clearDepth = 0.0
                
                //call the visionXR render graph
                guard let renderer else { return }
                renderer.renderXR(commandBuffer: commandBuffer,passDescriptor: passDescriptor, viewMatrix: cameraMatrix, projectionMatrix: projection, eyeIndex: viewIndex)
            }
            
            drawable.encodePresent(commandBuffer: commandBuffer)
            
            commandBuffer.commit()
        }
        
        func createPoseForTiming(at timing: LayerRenderer.Frame.Timing) -> DeviceAnchor? {
        
            guard worldTracking.state == .running else {
                return nil
            }
            
            // Convert compositor time -> Core Animation time
            let caTimestamp = compositorInstantToCATime(timing.presentationTime)
           
            /*
             if #available(visionOS 2.0, *) {
                 return worldTracking.queryDeviceAnchor(at: timing.presentationTime)
             } else {
                 let caTimestamp = compositorInstantToCATime(timing.presentationTime)
                 return worldTracking.queryDeviceAnchor(atTimestamp: caTimestamp)
             }

             */
            // Query ARKit for the predicted device anchor pose
            return worldTracking.queryDeviceAnchor(atTimestamp: caTimestamp)
         
        }
        
        @inline(__always)
        private func compositorInstantToCATime(_ instant: LayerRenderer.Clock.Instant) -> TimeInterval {
            let compositorClock = LayerRenderer.Clock()
            let nowInstant = compositorClock.now
            let nowCA = CACurrentMediaTime()

            // Compute duration between now and the target instant
            let duration: Duration = nowInstant.duration(to: instant)

            // Convert Duration → seconds
            let components = duration.components
            let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18

            return nowCA + seconds
        }
        
        @inline(__always)
        func makeProjectionMatrixFromTangents(
            tangents: simd_float4,   // [left, right, up, down]
            depthRange: simd_float2,   // [near, far]
            rightHanded: Bool = true
        ) -> simd_float4x4 {
            let left   = tangents.x * depthRange.x
            let right  = tangents.y * depthRange.x
            let up     = tangents.z * depthRange.x
            let down   = tangents.w * depthRange.x
            let nearZ  = depthRange.x
            let farZ   = depthRange.y

            let rl = 1.0 / (right - left)
            let tb = 1.0 / (up - down)
            let nf = 1.0 / (nearZ - farZ)

            if rightHanded {
                return simd_float4x4(
                    SIMD4<Float>(2 * nearZ * rl, 0, 0, 0),
                    SIMD4<Float>(0, 2 * nearZ * tb, 0, 0),
                    SIMD4<Float>((right + left) * rl, (up + down) * tb, (farZ + nearZ) * nf, -1),
                    SIMD4<Float>(0, 0, 2 * farZ * nearZ * nf, 0)
                )
            } else {
                // Left-handed variant
                return simd_float4x4(
                    SIMD4<Float>(2 * nearZ * rl, 0, 0, 0),
                    SIMD4<Float>(0, 2 * nearZ * tb, 0, 0),
                    SIMD4<Float>((right + left) * rl, (up + down) * tb, -(farZ + nearZ) * nf, 1),
                    SIMD4<Float>(0, 0, 2 * farZ * nearZ * nf, 0)
                )
            }
        }
        
    }

#endif
