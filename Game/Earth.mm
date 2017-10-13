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
#include "U4DParticleDust.h"
#include "U4DParticle.h"

using namespace U4DEngine;

void Earth::init(){
        
    //Set camera
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    U4DEngine::U4DVector3n cameraPos(0.0,0.0,-20.0);
    
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
    light->translateTo(0.0,100.0,-100.0);
    
    addChild(light);
    
    camera->viewInDirection(origin);

    //light->viewInDirection(origin);


    U4DParticle *particle=new U4DParticleDust();
    U4DVector4n color(1.0,1.0,0.0,1.0);
    particle->setDiffuseColor(color);
    
    particle->createParticles(0.25, 0.05, 1000, 0.1, nullptr);
    
    addChild(particle);
}

void Earth::update(double dt){

    U4DLights *light=U4DLights::sharedInstance();
    U4DCamera *camera=U4DCamera::sharedInstance();
    
    U4DVector3n cameraPos=camera->getAbsolutePosition();
    cameraPos.y=20.0;
    light->translateTo(cameraPos);
   
}





