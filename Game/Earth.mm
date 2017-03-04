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
#include "U4DSprite.h"
#include "U4DLights.h"
#include "U4DLogger.h"
#include "U11Ball.h"
#include "U11Field.h"
#include "U11Player.h"


using namespace U4DEngine;

void Earth::init(){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    camera->translateBy(0.0, 70.0, 90.0);
    camera->rotateBy(-36.0, 0.0, 0.0);
    
    setName("earth");
    
    enableShadows();
    
    ball=new U11Ball();
    ball->init("ball", "blenderscript.u4d");
    
    
    
    field=new U11Field();
    field->init("field0", "blenderscript.u4d");

    player=new U11Player();
    player->init("pele", "characterscript.u4d");
    
    
    //set ball entity
    field->setBallEntity(ball);
    
    player->setBallEntity(ball);
    
    U4DVector3n origin(0,0,0);

    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(5.0,5.0,5.0);
    light->viewInDirection(origin);
    
    addChild(ball);
    
    addChild(field);

    addChild(player);
    
}

void Earth::update(double dt){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    //camera->followModel(player, 0.0, 40.0, 0.0);
    

}





