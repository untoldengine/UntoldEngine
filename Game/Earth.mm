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
#include "SoccerPlayer.h"

using namespace U4DEngine;

void Earth::init(){
    
    rot=0.0;
    
    //Set camera
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    U4DEngine::U4DVector3n cameraPos(0.0,20.0,-50.0);
    
    camera->translateTo(cameraPos);
    
    
    setName("earth");
    //setEnableGrid(true);
    
    U4DDirector *director=U4DDirector::sharedInstance();
    
    director->setWorld(this);
    
    U4DVector3n origin(0,0,0);

    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(2.0,30.0,0.0);
    
    
    soccerPlayer=new SoccerPlayer();
    soccerPlayer->init("pele", "player.u4d");
    
    U4DVector3n fortPosition(0.0,11.5,0.0);
    soccerPlayer->translateTo(fortPosition);
    
    addChild(soccerPlayer);
    
    gameAsset2=new GameAsset();
    gameAsset2->init("plane", "plane.u4d");
    
    addChild(gameAsset2);
    
    U4DVector3n planePosition(0.0,-3.5,0.0);
    gameAsset2->translateTo(planePosition);
    
    
    addChild(light);
    
    
    camera->viewInDirection(origin);
    light->viewInDirection(origin);

    soccerPlayer->playAnimation();
}

void Earth::update(double dt){
    
}





