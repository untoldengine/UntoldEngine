//
//  GameScene.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/3/23.
//  Copyright © 2023 Untold Engine Studios. All rights reserved.
//

#include "GameScene.h"
#include "U4DTransformSystem.h"
#include "U4DLoadingSystem.h"
#include "U4DUtilsFunctions.h"
#include "CommonProtocols.h"

extern U4DEngine::KeyState keyState;
extern U4DEngine::EntityID player0ready;
void GameScene::init(MTKView *metalView){
    
    //Initialize the renderer
    renderer = [[U4DRenderer alloc] initWithMetalKitView:metalView];
    
    if(!renderer)
    {
        NSLog(@"Renderer failed initialization");
        return;
    }

    //Set your voxels entities
    U4DEngine::EntityID voxelEntity=scene.newEntity();
    scene.assign<U4DEngine::Voxel>(voxelEntity);
    scene.assign<U4DEngine::Transform>(voxelEntity);

    player0ready=scene.newEntity();
    scene.assign<U4DEngine::Voxel>(player0ready);
    scene.assign<U4DEngine::Transform>(player0ready);
//
//    U4DEngine::EntityID voxelEntity3=scene.newEntity();
//    scene.assign<U4DEngine::Voxel>(voxelEntity3);
//    scene.assign<U4DEngine::Transform>(voxelEntity3);
//    
//    U4DEngine::EntityID voxelEntity4=scene.newEntity();
//    scene.assign<U4DEngine::Voxel>(voxelEntity4);
//    scene.assign<U4DEngine::Transform>(voxelEntity4);
//    
//    U4DEngine::EntityID voxelEntity5=scene.newEntity();
//    scene.assign<U4DEngine::Voxel>(voxelEntity5);
//    scene.assign<U4DEngine::Transform>(voxelEntity5);
//    
//    U4DEngine::EntityID voxelEntity6=scene.newEntity();
//    scene.assign<U4DEngine::Voxel>(voxelEntity6);
//    scene.assign<U4DEngine::Transform>(voxelEntity6);
    
    U4DEngine::addVoxelsToEntity(voxelEntity,"lake.json");
    U4DEngine::translateTo(voxelEntity, simd_make_float3(0.0, 0.0, 0.0));
    
    U4DEngine::addVoxelsToEntity(player0ready,"ship.json");
    U4DEngine::translateTo(player0ready, simd_make_float3(0.0, 0.2, 0.0));
//
//    U4DEngine::addVoxelsToEntity(voxelEntity3,"puppy3.json");
//    U4DEngine::translateTo(voxelEntity3, simd_make_float3(5.0, 0.0, 0.0));
//    
//    U4DEngine::addVoxelsToEntity(voxelEntity4,"floorchunk.json");
//    U4DEngine::translateTo(voxelEntity4, simd_make_float3(0.0, -0.4, 0.0));
//    
//    U4DEngine::addVoxelsToEntity(voxelEntity5,"floorchunk.json");
//    U4DEngine::translateTo(voxelEntity5, simd_make_float3(6.0, -0.4, 0.0));
//    
//    U4DEngine::addVoxelsToEntity(voxelEntity6,"floorchunk.json");
//    U4DEngine::translateTo(voxelEntity6, simd_make_float3(-6.0, -0.4, 0.0));
    
    U4DEngine::setUpdateCallback(GameScene::update);
}

void GameScene::update(){
    GameScene gameScene;
    
    gameScene.handleInput();
    
    //U4DEngine::rotateBy(0, 1.0, simd_make_float3(0.0, 1.0, 0.0));
    
}

void GameScene::handleInput(){
    
    if(keyState.wPressed){
        U4DEngine::translateBy(player0ready, simd_make_float3(0.01,0.0,0.0));
    }
    
    if(keyState.sPressed){
        U4DEngine::translateBy(player0ready, simd_make_float3(-0.01,0.0,0.0));
    }
    
    if(keyState.aPressed){
        
    }
    
    
}
