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
#include "Floor.h"
#include "Tank.h"


using namespace U4DEngine;

void Earth::init(){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    camera->translateBy(0.0, 3.5, 8.0);
   
    setName("earth");
    tankBody=new Tank();
    tankBody->init("tankbody", "blenderscript.u4d");
    
    U4DVector3n origin(0,0,0);
    
    camera->viewInDirection(origin);

    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(5.0,5.0,5.0);
    light->viewInDirection(origin);
    
    addChild(tankBody);
    
    initLoadingModels();
    
    
}

void Earth::update(double dt){
    
    

}





