//
//  EngineRenderer.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/27/24.
//

import Foundation
import Metal
import MetalKit
import simd
import Spatial

class CoreRenderer: NSObject, MTKViewDelegate {
    
    var gameUpdateCallback: (() -> Void)?
    var handleInputCallback: (() -> Void)?
    
    init?(_ metalView:MTKView) {
    
        super.init()
        
        renderInfo.device=metalView.device
        renderInfo.colorPixelFormat=metalView.colorPixelFormat
        renderInfo.depthPixelFormat=metalView.depthStencilPixelFormat
        renderInfo.viewPort=simd_float2(Float(metalView.drawableSize.width),Float(metalView.drawableSize.height))
        
        //create a command queue
        guard let queue = renderInfo.device.makeCommandQueue() else { return nil }
        renderInfo.commandQueue=queue
        
#if os(iOS)
        let libraryURL=Bundle.main.url(forResource: "UntoldEngineKernels-ios", withExtension: "metallib")
#elseif os(macOS)
        let libraryURL=Bundle.main.url(forResource: "UntoldEngineKernels", withExtension: "metallib")
#elseif os(xrOS)
        let libraryURL=Bundle.main.url(forResource: "UntoldEngineKernels-xros", withExtension: "metallib")
#elseif os(xrOS)
#endif
        
        guard let mainLibrary=try? renderInfo.device.makeLibrary(URL: libraryURL!) else{
            
            Logger.logError(message: "Unable to find the metallib file")
            
            return nil
        }
        
        renderInfo.library=mainLibrary
        
        initGeneralBuffers()
        initMemoryPool()
        
        initCoreTextureResources()
        
        
        initGeneralRenderPipelines()
        initCoreRenderPipelines()
        initRenderPassDescriptors()
        renderInfo.fence = renderInfo.device.makeFence()
        
        camera=Camera()
        
        camera.lookAt(eye: simd_float3(0.0,3.0,7.0), target: simd_float3(0.0,0.0,0.0), up: simd_float3(0.0,1.0,0.0))
        
        lightingSystem=LightingSystem()
        
        let width:Float=100.0
        let height:Float=100.0
        
        lightingSystem.dirLight.orthoMatrix=matrix_ortho_right_hand(-width/2.0, width/2.0, -height/2.0, height/2.0, 0.1, farZ: 1000.0)
        
        
        Logger.log(message: "Engine Starting")
        
    }
    
    func update(){
       
        if (!firstUpdateCall) {
            
            //init the time properties for the update
            
            timeSinceLastUpdate = 0.0;
            
            timeSinceLastUpdatePreviousTime = CACurrentMediaTime();
            
            firstUpdateCall=true;
            
            //init fps time properties
            frameCount=0;
            timePassedSinceLastFrame=0.0;
            
        }else{
            
            // figure out the time since we last we drew
            let currentTime:TimeInterval = CACurrentMediaTime();
            
            timeSinceLastUpdate = currentTime - timeSinceLastUpdatePreviousTime;
            
            // keep track of the time interval between draws
            timeSinceLastUpdatePreviousTime = currentTime
            
            //get fps
            timePassedSinceLastFrame += Float(timeSinceLastUpdate);
            
            if(timePassedSinceLastFrame>0.1){
                
                //let fps:Float=Float(frameCount)/timePassedSinceLastFrame
                
                frameCount=0
                timePassedSinceLastFrame=0.0
                
            }
            
            //call the callback if it's set
            
            handleInputCallback?()
            
            gameUpdateCallback?()
        }
        
    }
    
    func draw(in view: MTKView) {
        
        update()
        
        if let commandBuffer=renderInfo.commandQueue.makeCommandBuffer(){
            
            if let renderPassDescriptor=view.currentRenderPassDescriptor{

                //call the update call before the render
                frameCount += 1;
                
                lightingSystem.dirLight.updateLightSpace()
                
                renderInfo.renderPassDescriptor=renderPassDescriptor
                
                //build a render graph
                var graph = [String: RenderPass]()
                
                let gridPass = RenderPass(id: "grid", dependencies: [], execute: CoreRenderPasses.gridExecution)
                graph[gridPass.id]=gridPass
                
                let shadowPass = RenderPass(id: "shadow", dependencies: ["grid"], execute: CoreRenderPasses.shadowExecution)
                
                graph[shadowPass.id]=shadowPass
                
                let voxelPass = RenderPass(id: "voxel", dependencies: ["shadow"], execute: CoreRenderPasses.voxelExecution)
                
                graph[voxelPass.id]=voxelPass
                
                let postProcess=RenderPass(id:"PostProcess",dependencies: ["voxel"],execute: CoreRenderPasses.executePostProcess(postProcessPipeline))
                
                graph[postProcess.id]=postProcess
                
                if(visualDebug==false){
                    let compositePass = RenderPass(id: "composite", dependencies: ["PostProcess"], execute: CoreRenderPasses.compositeExecution)
                    
                    graph[compositePass.id]=compositePass
                }else{
                    let debugPass = RenderPass(id: "debug", dependencies: ["PostProcess"], execute: CoreRenderPasses.debuggerExecution)
                    
                    graph[debugPass.id]=debugPass
                }
                
                //sorted it
                let sortedPasses = topologicalSortGraph(graph: graph)
                
                //execute it
                executeGraph(graph, sortedPasses, commandBuffer)
            
            }
            
            if let drawable=view.currentDrawable{
                commandBuffer.present(drawable)
            }
            
            commandBuffer.commit()
        }
        
        
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
        
        let aspect = Float(size.width) / Float(size.height)
        let projectionMatrix = matrixPerspectiveRightHand(fovyRadians: degreesToRadians(degrees: 65.0), aspectRatio:aspect, nearZ: 0.1, farZ: 100.0)
        
        renderInfo.perspectiveSpace=projectionMatrix
        
        let viewPortSize:simd_float2=simd_make_float2(Float(size.width),Float(size.height))
        renderInfo.viewPort=viewPortSize
    }
    
    
}



