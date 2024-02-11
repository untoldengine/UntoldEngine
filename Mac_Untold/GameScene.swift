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
        loadVoxelIntoPool(0, "room")
        //loadVoxelIntoPool(1, "bot1")
//        loadVoxelIntoPool(2, "pointLight1")
//        loadVoxelIntoPool(3, "pointLight2")
        
        //set up entities
        let entity0=scene.newEntity()
        var transform=scene.assign(to: entity0, component: Transform.self)
        _ = scene.assign(to: entity0, component: Render.self)
        
        transform.localSpace=matrix4x4Identity()
        
//        var entity1=scene.newEntity()
//        var transform1=scene.assign(to: entity1, component: Transform.self)
//        _ = scene.assign(to: entity1, component: Render.self)
        //transform1.localSpace=matrix4x4Translation(0.0, scale*2, 0.0)
        
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
        entityAssetMap[entity0]=assetDataArray[0]
        //entityAssetMap[entity1]=assetDataArray[1]
//        entityAssetMap[entity2]=assetDataArray[1]
//        
        //point lights
        //entityAssetMap[entity3]=assetDataArray[2]
//
        //set the callback to be the update method
        renderer.gameUpdateCallback = { [weak self] in
            self?.update()
        }
        
        renderer.handleInputCallback = {[weak self] in
            self?.handleInput()
        }
        //rotateTo(0, 45.0, simd_float3(0.0,1.0,0.0))
        //translateEntityBy(EntityID(1)<<32,simd_float3(2.0,0.0,0.0))
//        rotateTo(0, 90.0, simd_float3(0.0,1.0,0.0))
        //translateTo(0,-modelOffset)
    }
    
    func update(){
        //print("updating")
        //rotateBy(EntityID(1)<<32, 1.0, simd_float3(0.0,1.0,0.0))
    }
    
    func handleInput(){
        //print("user input")
        
        if keyState.aPressed == true{
            //rotateBy(0, 0.1, simd_float3(0.0,1.0,0.0))
            translateEntityBy(EntityID(1)<<32, simd_float3(-0.1,0.0,0.0))
        }
        
        if keyState.wPressed == true{
            
            translateEntityBy(EntityID(1)<<32, simd_float3(0.0,0.0,0.1))
        }
        
        if keyState.sPressed == true{
            
            translateEntityBy(EntityID(1)<<32, simd_float3(0.0,0.0,-0.1))
        }
        
        if keyState.dPressed == true{
            
            translateEntityBy(EntityID(1)<<32, simd_float3(0.1,0.0,0.0))
        }
        
    }
}
