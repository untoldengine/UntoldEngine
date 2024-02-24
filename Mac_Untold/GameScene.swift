//
//  GameScene.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/19/24.
//

import Foundation
import Metal
import MetalKit

class GameScene{
    
    var renderer: CoreRenderer!
    var mouseInitialPosition:simd_float2=simd_float2(0.0,0.0)
    
    init(_ metalView:MTKView) {
        
        //set up renderer here
        
        // Select the device to render with.  We choose the default device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }

        metalView.device = defaultDevice
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.colorPixelFormat = .rgba16Float
        metalView.preferredFramesPerSecond = 60
        metalView.framebufferOnly = false
        
        guard let newRenderer = CoreRenderer(metalView) else {
            print("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer
        //renderer.initRenderer(renderInfo: &renderInfo)
        renderer.mtkView(metalView, drawableSizeWillChange: metalView.drawableSize)
        
        metalView.delegate = renderer
        
        //init point lights
        var light0:PointLight=PointLight(position: simd_float4(0.0, 0.5, 1.0,0.0),
                                         color: simd_float4(2.0,0.0,0.0,0.0),
                                         attenuation: simd_float4(5.0,0.09,0.032,0.5),
                                         intensity: simd_float4(0.0,0.0,0.0,0.0));
        
        let light1:PointLight=PointLight(position: simd_float4(-1.0, 0.5, 1.0,0.0),
                                         color: simd_float4(0.0,0.0,1.0,0.0),
                                         attenuation: simd_float4(5.0,0.09,0.032,0.5),
                                         intensity: simd_float4(0.0,0.0,0.0,0.0));
        
        let light2:PointLight=PointLight(position: simd_float4(1.0, 0.5, 1.0,0.0),
                                         color: simd_float4(0.0,1.0,0.0,0.0),
                                         attenuation: simd_float4(5.0,0.09,0.032,0.5),
                                         intensity: simd_float4(0.0,0.0,0.0,0.0));
        
        //light0.setPosition(simd_float3(0.0, 0.5, 1.0))
        
        lightingSystem.pointLight.append(light0)
        lightingSystem.pointLight.append(light1)
        lightingSystem.pointLight.append(light2)
        lightingSystem.dirLight.direction=simd_float3(0.0,1.0,1.0)
        
        //load all assets
        loadVoxelIntoPool("room")
        loadVoxelIntoPool("bot1")
        
        //set up entities
        
        let entity0=createEntity()
        registerComponent(entity0,Render.self)
        registerComponent(entity0,Transform.self)
        registerGeometry(entity0,"room")
        
        
        let entity1=createEntityWithName(entityName: "block")
        registerComponent(entity1, Render.self)
        registerComponent(entity1, Transform.self)
        registerGeometry(entity1, "bot1")
        
//        var transform=scene.assign(to: entity0, component: Transform.self)
//        var render = scene.assign(to: entity0, component: Render.self)
//        
//        transform.localSpace=matrix4x4Translation(0.0, 0.0, 0.0)
//        render.voxel="room"
        
        
        /*
        var entity1=scene.newEntity()
        var transform1=scene.assign(to: entity1, component: Transform.self)
        var render1 = scene.assign(to: entity1, component: Render.self)
        transform1.localSpace=matrix4x4Translation(0.0, 0.0, 0.0)
        render1.voxel="bot1"
        */
        
//        transform1.localSpace=matrix4x4Translation(-4.0, 0.0, 0.0)
//        
//        var entity2=scene.newEntity()
//        _ = scene.assign(to: entity2, component: Transform.self)
//        _ = scene.assign(to: entity2, component: Render.self)
//        
//        var entity3=scene.newEntity()
//        var pointLightTransform = scene.assign(to: entity3, component: Transform.self)
//        _ = scene.assign(to: entity3, component: Render.self)
//        
//        pointLightTransform.localSpace=matrix4x4Translation(0.0, 0.5, 1.0)
        
        //linkEntityToAsset(entity0,0)
        
//        assetDataMap[entity2]=assetDataArray[1]
//        
        //point lights
        //assetDataMap[entity3]=assetDataArray[2]
//
        //set the callback to be the update method
        renderer.gameUpdateCallback = { [weak self] deltaTime in
            self?.update(deltaTime)
        }
        
        renderer.handleInputCallback = {[weak self] in
            self?.handleInput()
        }
        //rotateTo(0, 45.0, simd_float3(0.0,1.0,0.0))
        //translateEntityBy(EntityID(1)<<32,simd_float3(2.0,0.0,0.0))
//        rotateTo(0, 90.0, simd_float3(0.0,1.0,0.0))
        //translateTo(0,-modelOffset)
    }
    
    func update(_ deltaTime:Float){
        //print("updating")
        //rotateBy(EntityID(1)<<32, 1.0, simd_float3(0.0,1.0,0.0))
        
        guard let block=queryEntityWithName(entityName: "block") else{
            return
        }
        movementSystem.update(block, deltaTime)
    }
    
    func handleInput(){
        //print("user input")
        
        guard let block=queryEntityWithName(entityName: "block") else{
            return
        }
        
        if inputSystem.currentPanGestureState == .changed{
            let n:simd_float2=(inputSystem.panDelta)
            rotateBy(block, 1.0, simd_float3(0.0,1.0,0.0))
        }
        if inputSystem.keyState.aPressed == true{
            //rotateBy(0, 0.1, simd_float3(0.0,1.0,0.0))
            
            //translateEntityBy(block, simd_float3(-0.1,0.0,0.0))
        }
        
        if inputSystem.keyState.wPressed == true{
            
            //translateEntityBy(block, simd_float3(0.0,0.0,0.1))
        }
        
        if inputSystem.keyState.sPressed == true{
            
            //translateEntityBy(block, simd_float3(0.0,0.0,-0.1))
        }
        
        if inputSystem.keyState.dPressed == true{
            //translateEntityBy(block, simd_float3(0.1,0.0,0.0))
        }
        
    }
}
