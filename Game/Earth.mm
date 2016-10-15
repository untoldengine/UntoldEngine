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
#include "Floor.h"

using namespace U4DEngine;

void Earth::init(){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    camera->translateBy(0.0, 1.0, 6.0);
    //camera->rotateTo(0.0,-20.0,0.0);
   
    //create character
    ninja=new MyCharacter();
    ninja->init("ninja", "characterscript.u4d");
    
    //create the floor
    floor=new Floor();
    floor->init("platform1","characterscript.u4d");
    
    U4DVector3n origin(0,0,0);
    
    camera->viewInDirection(origin);

    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(5.0,5.0,5.0);
    light->viewInDirection(origin);
    
    addChild(ninja);
    
    addChild(floor);
    
    initLoadingModels();
    
    
}

void Earth::update(double dt){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    camera->followModel(ninja, 0.0, 1.0, 2.0);
    

}

void Earth::action(){
    
    setEntityControlledByController(ninja);
    
}




