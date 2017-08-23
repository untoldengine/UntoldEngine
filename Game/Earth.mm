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
#include "ModelAsset.h"
#include "SoccerPlayer.h"

#include "U4DFontLoader.h"

using namespace U4DEngine;

void Earth::init(){
    
    //Set camera
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    U4DEngine::U4DVector3n cameraPos(0.0,15.0,-70.0);
    
    camera->translateTo(cameraPos);
    
    
    setName("earth");
    //setEnableGrid(true);
    
    U4DDirector *director=U4DDirector::sharedInstance();
    
    director->setWorld(this);
    
    //compute perspective space
    U4DEngine::U4DMatrix4n perspectiveSpace=director->computePerspectiveSpace(45.0f, director->getAspect(), 0.1f, 300.0f);
    director->setPerspectiveSpace(perspectiveSpace);
    
    //compute orthographic shadow space
    U4DEngine::U4DMatrix4n orthographicShadowSpace=director->computeOrthographicSpace(-10.0, 10.0, -10.0, 10.0, -10.0, 10.0f);
    director->setOrthographicShadowSpace(orthographicShadowSpace);
    
    U4DVector3n origin(0,0,0);

    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(0.0,50.0,-1.0);
    
    addChild(light);
    
    
    camera->viewInDirection(origin);

    player=new SoccerPlayer();
    player->init("pele","player.u4d","redkitnormal.png");
    
    addChild(player);
    
    ball=new ModelAsset();
    ball->init("ball","blenderscript.u4d","Ball_Normal_Map.png");
    
    addChild(ball);
    
    fieldGoal1=new GameAsset();
    fieldGoal1->init("fieldgoal1", "blenderscript.u4d");
    
    addChild(fieldGoal1);
    
    fieldGoal2=new GameAsset();
    fieldGoal2->init("fieldgoal2", "blenderscript.u4d");
    
    addChild(fieldGoal2);
    
    field=new GameAsset();
    field->init("field", "blenderscript.u4d");
    
    
    
    light->viewInDirection(origin);
    
    //GameLogic *gameModel=dynamic_cast<GameLogic*>(getGameModel());
    //gameModel->setMainPlayer(player);
    
    U4DFontLoader *fontLoader=new U4DFontLoader();
    
    fontLoader->loadFontAssetFile("myFont.xml", "myFont.png");
    
    myText1=new U4DText(fontLoader, 30);
    
    myText1->setText("Untold Engine");
    
    addChild(myText1);
    
    myText1->translateTo(0.0, 0.0, 0.0);
    
    addChild(field);
}

void Earth::update(double dt){

    //U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    
    //camera->followModel(player, 0.0, 15.0, -70.0);
    
   
}





