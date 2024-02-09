//
//  VoxelRenderer.swift
//  UntoldEditor
//
//  Created by Harold Serrano on 11/11/23.
//

import Foundation
import Metal
import MetalKit
import simd
import Spatial

class EditorRenderer: NSObject, MTKViewDelegate {
    
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
        initEditorBuffers()
        
        initEditorTextureResources()
        initRenderPassDescriptors()
        
        initGeneralRenderPipelines()
        initEditorRenderPipelines()
        
        initEditorComputePipeline()
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
                
                enableRayVoxelIntersection=true
                frameCount=0
                timePassedSinceLastFrame=0.0
                
            }
            
        }
        
    }
    
    func draw(in view: MTKView) {
        
        if let commandBuffer=renderInfo.commandQueue.makeCommandBuffer(){
            
            if let renderPassDescriptor=view.currentRenderPassDescriptor{

                //call the update call before the render
                frameCount += 1;
                
                lightingSystem.dirLight.updateLightSpace()
                
                renderInfo.renderPassDescriptor=renderPassDescriptor
                
                //executeEnvironmentPass(commandBuffer)
//                executeGridPass(uCommandBuffer: commandBuffer)
//                executeEditorVoxelPass(uCommandBuffer: commandBuffer)
//                
//                executeGhostVoxelPass(uCommandBuffer: commandBuffer)
//                executeCompositePass(uCommandBuffer: commandBuffer)
                
                
                //build a render graph
                var graph = [String: RenderPass]()
                
                let gridPass = RenderPass(id: "grid", dependencies: [], execute: CoreRenderPasses.gridExecution)
                graph[gridPass.id]=gridPass
                
                let voxelPass = RenderPass(id: "voxel", dependencies: ["grid"], execute: EditorRenderPasses.EditorVoxelExecution)
                
                graph[voxelPass.id]=voxelPass
                
                let ghostVoxelPass = RenderPass(id: "ghost_voxel", dependencies: ["voxel"], execute: EditorRenderPasses.EditorGhostVoxelExecution)
                
                graph[ghostVoxelPass.id]=ghostVoxelPass
                
                let compositePass = RenderPass(id: "composite", dependencies: ["ghost_voxel"], execute: CoreRenderPasses.compositeExecution)
                
                graph[compositePass.id]=compositePass
                
                //sorted it
                let sortedPasses = topologicalSortGraph(graph: graph)
                
                //execute it
                executeGraph(graph, sortedPasses, commandBuffer)
                
                
                //pre-process the ibl maps
        //        if(iblMipmapped == true && iblPreFilterComplete == false){
        //            if let iblPreFilterMapsCommandBuffer = renderInfo.commandQueue.makeCommandBuffer(){
        //
        //                executeIBLPreFilterPass(uCommandBuffer: iblPreFilterMapsCommandBuffer)
        //                iblPreFilterProcessing=true
        //                //add a completion handler here
        //                iblPreFilterMapsCommandBuffer.addCompletedHandler{(_ commandBuffer)-> Swift.Void in
        //
        //                    iblPreFilterComplete=true
        //                }
        //                iblPreFilterMapsCommandBuffer.commit()
        //            }
        //        }
            
            }
            
            if let drawable=view.currentDrawable{
                commandBuffer.present(drawable)
            }
            
            commandBuffer.commit()
        }
        
        update()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
        
        let aspect = Float(view.frame.size.width) / Float(view.frame.size.height)
        let projectionMatrix = matrixPerspectiveRightHand(fovyRadians: degreesToRadians(degrees: 65.0), aspectRatio:aspect, nearZ: 0.1, farZ: 100.0)
        
        renderInfo.perspectiveSpace=projectionMatrix
        
        let viewPortSize:simd_float2=simd_make_float2(Float(view.frame.size.width),Float(view.frame.size.height))
        renderInfo.viewPort=viewPortSize
        
    }
    
    
    //VISION PRO
    func visionOSRenderGraphc(_ commandBuffer:MTLCommandBuffer,
                              _ renderPassDescriptor: MTLRenderPassDescriptor,
                              _ projectionMatrix: ProjectiveTransform3D,
                              _ cameraMatrix: matrix_float4x4,
                              _ index:UInt8){
        
        //update vision os matrices
        camera.viewSpace = cameraMatrix
        renderInfo.renderPassDescriptor=renderPassDescriptor
        
        let projectionMatrixDouble: simd_double4x4 = projectionMatrix.matrix
        
        // Convert it to simd_float4x4
        let projectionMatrixFloat = matrix_float4x4_from_double4x4(projectionMatrixDouble)

        renderInfo.perspectiveSpace = projectionMatrixFloat
        
        frameCount += 1;
        
        executeEnvironmentVisionPass(commandBuffer, renderPassDescriptor)
        executeEditorVoxelVisionPass(commandBuffer, renderPassDescriptor)
        executeGhostVoxelVisionPass(commandBuffer, renderPassDescriptor)
        executeCompositeVisionPass(commandBuffer, renderPassDescriptor)
        //pre-process the ibl maps
        if(iblMipmapped == true && iblPreFilterComplete == false){
            if let iblPreFilterMapsCommandBuffer = renderInfo.commandQueue.makeCommandBuffer(){
                
                executeIBLPreFilterPass(uCommandBuffer: iblPreFilterMapsCommandBuffer)
                iblPreFilterProcessing=true
                //add a completion handler here
                iblPreFilterMapsCommandBuffer.addCompletedHandler{(_ commandBuffer)-> Swift.Void in
                    
                    iblPreFilterComplete=true
                }
                iblPreFilterMapsCommandBuffer.commit()
            }
        }
        
    }
    
    //Place these function in a system
    func removeAllVoxels(){
        //reset the stack
//        undoStack=[UserOperation]()
//        redoStack=[UserOperation]()
        undoStack.clear()
        redoStack.clear()
        
        if let commandBuffer=renderInfo.commandQueue.makeCommandBuffer(){
            executeRemoveAllVoxels(uCommandBuffer: commandBuffer)
            commandBuffer.commit()
        }
    }
    
    
    func serializeVoxels(filePath: String, directoryURL: URL){
        if let commandBuffer=renderInfo.commandQueue.makeCommandBuffer(){
            executeSerializeVoxels(uCommandBuffer: commandBuffer)
            
            commandBuffer.addCompletedHandler{(_ commandBuffer)-> Swift.Void in
                
                let bufferPointerCount=UnsafeRawBufferPointer(start: editorBufferResources.voxelSerializeCountBuffer!.contents(), count: 1).bindMemory(to: UInt16.self)

                let count:UInt16=bufferPointerCount.baseAddress!.pointee
        
                let dataPointer = editorBufferResources.serializeBuffer!.contents().assumingMemoryBound(to: VoxelData.self)
                let voxelDataArray = Array(UnsafeBufferPointer(start: dataPointer, count: Int(count)))
                
                saveArrayOfStructsToFile(dataArray: voxelDataArray, filePath: filePath, directoryURL: directoryURL)
                
                var zero:UInt=0
                editorBufferResources.voxelSerializeCountBuffer!.contents().copyMemory(from: &zero, byteCount: MemoryLayout<UInt>.stride)
            }
            
            commandBuffer.commit()
        }
    }
    
}

