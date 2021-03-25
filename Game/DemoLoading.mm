//
//  DemoLoading.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/7/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "DemoLoading.h"
#include "U4DDirector.h"
#include "UserCommonProtocols.h"
#include "U4DShaderEntity.h"
#include "U4DResourceLoader.h"
#include "U4DRenderManager.h"
#include "U4DShaderEntityPipeline.h"

using namespace U4DEngine;

DemoLoading::DemoLoading(){
    
}

DemoLoading::~DemoLoading(){
    
    delete loadingBackgroundImage;
    
}

void DemoLoading::init(){
 
    U4DEngine::U4DResourceLoader *resourceLoader=U4DEngine::U4DResourceLoader::sharedInstance();

    //Load binary file with texture data
    resourceLoader->loadTextureData("sceneTextures.u4d");
    
    //Add image
    loadingBackgroundImage=new U4DEngine::U4DImage();
    
    //set the image to use and the desire width and height
    
    U4DDirector *director=U4DDirector::sharedInstance();
    
    //use the dimensions of the display
    float width=director->getDisplayWidth();
    float height=director->getDisplayHeight();
    
    loadingBackgroundImage->setImage("loadingscreen.png",width,height);
    
    addChild(loadingBackgroundImage);
    
    
    //create a new pipeline for the loading circle shader
    U4DShaderEntityPipeline* shaderPipeline=new U4DShaderEntityPipeline("loadingcirclepipeline");
    
    shaderPipeline->initPipeline("vertexLoadingCircleShader","fragmentLoadingCircleShader");
    
    //create the loading circle shader entity
    U4DEngine::U4DShaderEntity *shader=new U4DEngine::U4DShaderEntity(0);
    
    //link the pipeline to the entity
    shader->setPipeline("loadingcirclepipeline");
    
    shader->setShaderDimension(width/2.0, height/2.0);
    
    shader->translateTo(0.0, -0.3, 0.0);
    
    shader->loadRenderingInformation();
    
    addChild(shader,-10);
}


void DemoLoading::update(double dt){
    
}
