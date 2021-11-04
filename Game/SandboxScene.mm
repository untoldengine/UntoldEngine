//
//  SandboxScene.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/13/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "SandboxScene.h"
#include "U4DResourceLoader.h"
#include "U4DModelPipeline.h"

SandboxScene::SandboxScene(){
    
}

SandboxScene::~SandboxScene(){
    
    delete sandboxWorld;
    delete sandboxLogic;
    delete loadingScene;
    
}

void SandboxScene::init(){
    
    //create view component
    sandboxWorld=new SandboxWorld();
    
    //create loading screen
    loadingScene=new SandboxLoading();
    
    //create model component
    sandboxLogic=new SandboxLogic();
    
    /*---LOAD SCENE ASSETS HERE--*/
    //Load binary file with scene data
    U4DEngine::U4DResourceLoader *resourceLoader=U4DEngine::U4DResourceLoader::sharedInstance();
    
    //The spaceScene.u4d file contains the data for the astronaut model and ground
    //All of the .u4d files are found in the Resource folder. Note, you will need to use the Digital Asset Converter tool to convert all game asset data into .u4d files. For more info, go to www.untoldengine.com.
    resourceLoader->loadSceneData("soccerScene.u4d");

    //Load binary file with texture data for the astronaut
    resourceLoader->loadTextureData("soccerTextures.u4d");
    
    //load ui textures contains images that can be used for the UIs. Look at the joystick instance below.
    resourceLoader->loadTextureData("uiTextures.u4d");
    
    //load particle data
    //resourceLoader->loadParticleData("redBulletEmitter.u4d");
    
    //Load binary file with animation data
    resourceLoader->loadAnimationData("rightshotAnimation.u4d");
    resourceLoader->loadAnimationData("runningAnimation.u4d");
    
    //load font data. In this example, the font is used for the UIs.
    resourceLoader->loadFontData("uiFont.u4d");
    
    U4DEngine::U4DModelPipeline *testPipeline=new U4DEngine::U4DModelPipeline("testPipeline");
        
    testPipeline->initPipeline("vertexTestPipelineShader", "fragmentTestPipelineShader");
    
    U4DEngine::U4DModelPipeline *nonvisiblePipeline=new U4DEngine::U4DModelPipeline("nonvisible");
        
    nonvisiblePipeline->initPipeline("vertexNonVisibleShader", "fragmentNonVisibleShader");

    loadComponents(sandboxWorld, sandboxLogic,true);
    
    //anchor mouse
//    setAnchorMouse(true);
//
//    [NSCursor hide];
}
