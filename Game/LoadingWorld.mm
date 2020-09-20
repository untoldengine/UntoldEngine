//
//  LoadingWorld.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/19/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "LoadingWorld.h"
#include "U4DSprite.h"
#include "U4DSpriteAnimation.h"
#include "U4DDirector.h"
#include "UserCommonProtocols.h"
#include "U4DShaderEntity.h"

using namespace U4DEngine;

LoadingWorld::LoadingWorld(){
    
}

LoadingWorld::~LoadingWorld(){
    
    delete loadingBackgroundImage;
    
}

void LoadingWorld::init(){
    
    //Add image
    loadingBackgroundImage=new U4DEngine::U4DImage();
    
    //set the image to use and the desire width and height
    
    U4DDirector *director=U4DDirector::sharedInstance();
    
    //use the dimensions of the display
    float width=director->getDisplayWidth();
    float height=director->getDisplayHeight();
    
    loadingBackgroundImage->setImage("footballerloadingscreen.png",width,height);
    
    addChild(loadingBackgroundImage);
    
    U4DEngine::U4DShaderEntity *shader=new U4DEngine::U4DShaderEntity(0);
    
    shader->setShader("vertexLoadingCircleShader","fragmentLoadingCircleShader");
    
    shader->setShaderDimension(width/2.0, height/2.0);
    
    shader->translateTo(0.0, -0.3, 0.0);
    
    shader->loadRenderingInformation();
    
    addChild(shader,-10);
}


void LoadingWorld::update(double dt){
    
}


