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
        
        
        let entity1=createEntityWithName(entityName: "player0")
        registerComponent(entity1, Render.self)
        registerComponent(entity1, Transform.self)
        registerGeometry(entity1, "bot1")
        

        //set the callback to be the update method
        renderer.gameUpdateCallback = { [weak self] deltaTime in
            self?.update(deltaTime)
        }
        
        renderer.handleInputCallback = {[weak self] in
            self?.handleInput()
        }
       
    }
    
    func update(_ deltaTime:Float){
        
        guard let player=queryEntityWithName(entityName: "player0") else{
            return
        }
        
        movementSystem.update(player, deltaTime)
        
        basicFollow(player,simd_float3(0.0,3.0,5.0), deltaTime)
        
    }
    
    func handleInput(){

        
        guard let player=queryEntityWithName(entityName: "player0") else{
            return
        }
        
        if inputSystem.currentPanGestureState == .changed{
            let n:simd_float2=(inputSystem.panDelta)
            rotateBy(player, n.x, simd_float3(0.0,1.0,0.0))
        }
        if inputSystem.keyState.aPressed == true{
            
        }
        
        if inputSystem.keyState.wPressed == true{
            
            
        }
        
        if inputSystem.keyState.sPressed == true{
            
           
        }
        
        if inputSystem.keyState.dPressed == true{
            
        }
        
    }
}
