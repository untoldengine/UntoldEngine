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
#include "Floor.h"

using namespace U4DEngine;

void Earth::init(){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    camera->translateBy(0.0, 5.0, 10.0);
    
    setName("earth");
    
    enableShadows();
    
    ball=new SoccerBall();
    ball->init("ball", "blenderscript.u4d");
    
    field=new SoccerField();
    field->init("field", "blenderscript.u4d");
    
    player=new SoccerPlayer();
    player->init("player", "blenderscript.u4d");
    
    box1=new Floor();
    box1->init("box1", "blenderscript.u4d");
    
    box2=new Floor();
    box2->init("box2", "blenderscript.u4d");
    
    box3=new Floor();
    box3->init("box3", "blenderscript.u4d");
    
    box4=new Floor();
    box4->init("box4", "blenderscript.u4d");
    
    U4DVector3n origin(0,0,0);
    
    camera->viewInDirection(origin);

    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(5.0,5.0,5.0);
    light->viewInDirection(origin);
    
    addChild(ball);
    
    //addChild(field);
    
    addChild(player);
/*
    addChild(box1);
    
    addChild(box2);
    
    addChild(box3);
    
    addChild(box4);
    */
}

void Earth::update(double dt){
    
    //U4DCamera *camera=U4DCamera::sharedInstance();
    //camera->followModel(rocket, 0.0, 2.0, 3.5);
    

}





