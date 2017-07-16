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
#include "U4DButton.h"
#include "U4DSkyBox.h"
#include "U4DTouches.h"
#include "U4DCamera.h"
#include "U4DControllerInterface.h"

#include "GameController.h"
#include "U4DLights.h"
#include "U4DLogger.h"


#include "GameLogic.h"
#include "GameAsset.h"

using namespace U4DEngine;

void Earth::init(){
    
    //Set camera
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    U4DEngine::U4DVector3n cameraPos(0.0,10.0,-20.0);
    
    camera->translateTo(cameraPos);
    
    
    setName("earth");
    //setEnableGrid(true);
    
    U4DDirector *director=U4DDirector::sharedInstance();
    
    director->setWorld(this);
    
    U4DVector3n origin(0,0,0);

    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(5.0,5.0,-5.0);
    light->viewInDirection(origin);
    
    gameAsset=new GameAsset();
    gameAsset->init("fort", "fort.u4d");
    
    addChild(gameAsset);
    
    gameAsset2=new GameAsset();
    gameAsset2->init("plane", "plane.u4d");
    
    addChild(gameAsset2);
    
    U4DVector3n planePosition(0.0,-3.0,0.0);
    gameAsset2->translateTo(planePosition);
    
    addChild(light);
    camera->viewInDirection(origin);
}

void Earth::update(double dt){
    
}





