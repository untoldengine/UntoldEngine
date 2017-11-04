//
//  Earth.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "Earth.h"

#include "CommonProtocols.h"

#include <stdio.h>

#include "U4DDirector.h"

#include "U4DMatrix3n.h"
#include "U4DCamera.h"
#include "U4DControllerInterface.h"

#include "GameController.h"
#include "U4DLights.h"
#include "U4DLogger.h"


#include "GameLogic.h"

#include "GameAsset.h"
#include "ModelAsset.h"

#include "U4DParticleSystem.h"
#include "U4DParticleData.h"
#include "U4DParticleEmitterInterface.h"
#include "U4DParticleEmitterLinear.h"

using namespace U4DEngine;

void Earth::init(){
        
    //Set camera
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    U4DEngine::U4DVector3n cameraPos(0.0,5.0,-10.0);
    
    camera->translateTo(cameraPos);
    
    
    setName("earth");
    setEnableGrid(false);
    
    U4DDirector *director=U4DDirector::sharedInstance();
    
    director->setWorld(this);
    
    //compute perspective space
    U4DEngine::U4DMatrix4n perspectiveSpace=director->computePerspectiveSpace(30.0f, director->getAspect(), 0.01f, 100.0f);
    director->setPerspectiveSpace(perspectiveSpace);
    
    //compute orthographic shadow space
    U4DEngine::U4DMatrix4n orthographicShadowSpace=director->computeOrthographicSpace(-100.0f, 100.0f, -100.0f, 100.0f, -100.0f, 100.0f);
    director->setOrthographicShadowSpace(orthographicShadowSpace);
    
    U4DVector3n origin(0,0,0);

    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(0.0,10.0,0.0);
    
    addChild(light);
    
    camera->viewInDirection(origin);

    light->viewInDirection(origin);
    
    floor=new ModelAsset();
    floor->init("Floor", "blenderscript.u4d");
    
    
    addChild(floor,5);
    
    fontLoader=new U4DEngine::U4DFontLoader();
    fontLoader->loadFontAssetFile("ArialFont.xml", "ArialFont.png");
    
    text=new U4DEngine::U4DText(fontLoader,30);
    
    text->setText("Untold Engine");
    
    addChild(text,0);
    
    skybox=new U4DEngine::U4DSkybox();
    skybox->initSkyBox(40.0, "RightImage.png", "LeftImage.png", "TopImage.png", "BottomImage.png", "FrontImage.png", "BackImage.png");
    
    addChild(skybox,1);
    
}

Earth::~Earth(){
    
    
    delete floor;
    
}

void Earth::update(double dt){
    
}





