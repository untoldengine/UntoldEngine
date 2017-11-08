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
#include "GuardianModel.h"

#include "U4DParticleSystem.h"
#include "U4DParticleData.h"
#include "U4DParticleEmitterInterface.h"
#include "U4DParticleEmitterLinear.h"
#include "U4DSpriteLoader.h"
#include "U4DSprite.h"
#include "U4DSpriteAnimation.h"

#include "U4DFontLoader.h"
#include "U4DText.h"

using namespace U4DEngine;

void Earth::init(){
        
    //Set camera
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    U4DEngine::U4DVector3n cameraPos(0.0,10.0,-15.0);
    
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
    light->translateTo(0.0,19.0,0.0);
    U4DEngine::U4DVector3n diffuse(0.5,0.5,0.5);
    U4DEngine::U4DVector3n specular(0.1,0.1,0.1);
    light->setDiffuseColor(diffuse);
    light->setSpecularColor(specular);
    addChild(light);
    
    camera->viewInDirection(origin);

    light->viewInDirection(origin);
    
    //add terrain
    terrain=new ModelAsset();

    if(terrain->init("terrain","blenderscript.u4d")){
        addChild(terrain);
    }

    
    //add character
    guardian=new GuardianModel();
    
    if(guardian->init("guardian","guardianscript.u4d")){
        addChild(guardian);
    }
    
    guardian->translateBy(0.0, 0.0, -4.0);
    
    //get game model pointer
    GameLogic *gameModel=dynamic_cast<GameLogic*>(getGameModel());
    
    gameModel->setGuardian(guardian);
    
}

Earth::~Earth(){
    
    
}

void Earth::update(double dt){
    
    U4DCamera *camera=U4DCamera::sharedInstance();

    camera->followModel(guardian, 0.0, 10.0, -15.0);
}





