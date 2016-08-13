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
#include "Rocket.h"
#include "Mountain.h"
#include "Planet.h"
#include "Meteor.h"

using namespace U4DEngine;

void Earth::init(){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    camera->translateBy(0.0, 3.0, 10.0);
    //camera->rotateTo(0.0,-20.0,0.0);

    setName("earth");

    //create the floor
    floor=new Floor();
    floor->init("GroundFloor","blenderscript.u4d");
    
//    //create the rocket
//    rocket=new Rocket();
//    rocket->init("Rocket","blenderscript.u4d");
//    
//    //create mountain
//    mountain=new Mountain();
//    mountain->init("Mountain", "blenderscript.u4d");
//    
//    mountain2=new Mountain();
//    mountain2->init("Mountain2", "blenderscript.u4d");
//    
//    mountain3=new Mountain();
//    mountain3->init("Mountain3", "blenderscript.u4d");
//    
//    mountain4=new Mountain();
//    mountain4->init("Mountain4", "blenderscript.u4d");
//    
//    //create planet
//    planet=new Planet();
//    planet->init("Planet", "blenderscript.u4d");
//    
//    //create meteors
//    meteor1=new Meteor();
//    meteor1->init("Meteor1", "blenderscript.u4d");
//    
//    meteor2=new Meteor();
//    meteor2->init("Meteor2", "blenderscript.u4d");
    
    meteor3=new Meteor();
    meteor3->init("Icosphere", "blenderscript.u4d");

    U4DVector3n origin(0,0,0);
    
    camera->viewInDirection(origin);
    

    addChild(floor);
//    addChild(rocket);
//    addChild(mountain);
//    addChild(mountain2);
//    addChild(mountain3);
//    addChild(mountain4);
//    addChild(planet);
//    addChild(meteor1);
//    addChild(meteor2);
    addChild(meteor3);

    
    
    initLoadingModels();
    
    
}

void Earth::update(double dt){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    //camera->followModel(rocket, 0.0, 2.0, 10.0);
    

}

void Earth::action(){
    
    setEntityControlledByController(rocket);
    
}




