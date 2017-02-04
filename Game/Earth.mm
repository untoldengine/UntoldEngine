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

#include "MyCharacter.h"
#include "U4DMatrix3n.h"
#include "U4DButton.h"
#include "U4DSkyBox.h"
#include "U4DTouches.h"
#include "U4DCamera.h"
#include "U4DControllerInterface.h"

#include "GameController.h"
#include "U4DSprite.h"
#include "U4DLights.h"
#include "U4DLogger.h"
#include "SoccerBall.h"
#include "SoccerField.h"
#include "SoccerPlayer.h"
#include "SoccerPost.h"
#include "SoccerPostSensor.h"
#include "SoccerGoalSensor.h"

using namespace U4DEngine;

void Earth::init(){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    camera->translateBy(0.0, 20.0, 40.0);
    camera->rotateBy(-26.0, 0.0, 0.0);
    
    setName("earth");
    
    enableShadows();
    
    ball=new SoccerBall();
    ball->init("ball", "blenderscript.u4d");
    
    field=new SoccerField();
    field->init("field", "blenderscript.u4d");
    
    post=new SoccerPost();
    post->init("goalpost", "blenderscript.u4d");

    
    postSensorLeft=new SoccerPostSensor();
    postSensorLeft->init("leftpostsensor", "blenderscript.u4d");
    
    postSensorRight=new SoccerPostSensor();
    postSensorRight->init("rightpostsensor", "blenderscript.u4d");
    
    postSensorTop=new SoccerPostSensor();
    postSensorTop->init("toppostsensor", "blenderscript.u4d");
    
    postSensorBack=new SoccerPostSensor();
    postSensorBack->init("backpostsensor", "blenderscript.u4d");
    
    //goalSensor=new SoccerGoalSensor();
    //goalSensor->init("goalsensor", "blenderscript.u4d");
    
    
    //set ball entity
    field->setBallEntity(ball);
    
    postSensorLeft->setBallEntity(ball);
    postSensorRight->setBallEntity(ball);
    postSensorTop->setBallEntity(ball);
    postSensorBack->setBallEntity(ball);
    
    
    //goalSensor->setBallEntity(ball);
    
    //player=new SoccerPlayer();
    //player->init("player", "blenderscript.u4d");
    
    U4DVector3n origin(0,0,0);
    
    //camera->viewInDirection(origin);

    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(5.0,5.0,5.0);
    light->viewInDirection(origin);
    
    addChild(ball);
    
    addChild(field);
    
    addChild(post);

    addChild(postSensorLeft);
    
    addChild(postSensorRight);
    
    addChild(postSensorBack);
    
    addChild(postSensorTop);
    
    //addChild(goalSensor);
    
    //addChild(player);

}

void Earth::update(double dt){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    //camera->followModel(ball, 10.0, 20.0, 20.0);
    

}





