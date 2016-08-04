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
#include "U4DDebugger.h"
#include "Floor.h"
#include "Rocket.h"
#include "Mountain.h"
#include "Planet.h"
#include "Meteor.h"

void Earth::init(){
    
    U4DEngine::U4DDebugger *debugger=new U4DEngine::U4DDebugger();
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    camera->translateBy(0.0, 3.0, 10.0);
    //camera->rotateTo(0.0,-20.0,0.0);
    
    setName("earth");
    
    //create the floor
    floor=new Floor();
    floor->init("GroundFloor","blenderscript.u4d");
    
    //create the rocket
    rocket=new Rocket();
    rocket->init("Rocket","blenderscript.u4d");
    
    //create mountain
    mountain=new Mountain();
    mountain->init("Mountain", "blenderscript.u4d");
    
    mountain2=new Mountain();
    mountain2->init("Mountain2", "blenderscript.u4d");
    
    mountain3=new Mountain();
    mountain3->init("Mountain3", "blenderscript.u4d");
    
    mountain4=new Mountain();
    mountain4->init("Mountain4", "blenderscript.u4d");
    
    //create planet
    planet=new Planet();
    planet->init("Planet", "blenderscript.u4d");
    
    //create meteors
    meteor1=new Meteor();
    meteor1->init("Meteor1", "blenderscript.u4d");
    
    meteor2=new Meteor();
    meteor2->init("Meteor2", "blenderscript.u4d");
    
    meteor3=new Meteor();
    meteor3->init("Meteor3", "blenderscript.u4d");
    
    //create our object
//    cube=new Town();
//    cube->init("GroundFloor",0.0,0.0,0.0);
//    cube->setName("cube");
    
//    //cube->setAsGround(true);
//    //Apply the collision engine to the object
//    //cube->enableCollision();
//    //cube->setMass(1.0);
//    //cube->setCoefficientOfRestitution(0.7);
//    
//    //cube->setNarrowPhaseBoundingVolumeVisibility(true);
//    
//    cube2=new Town();
//    cube2->init("Cube",0.0,0.0,0.0);
//    
//    cube2->setName("cube2");
    
//    cube3=new Town();
//    cube3->init("Cube3",-3.0,1.0,0.0);
//    cube3->setShader("simpleShader");
//    cube3->setName("cube3");
    
    
    //cube2->rotateBy(0.0,0.0,60.0);
    //cube2->setMass(1.0);
    //cube2->setCoefficientOfRestitution(0.6);
    //cube2->applyPhysics(true);

    //cube2->enableCollision();
    
    //cube2->setNarrowPhaseBoundingVolumeVisibility(true);

    U4DEngine::U4DLights *light=new U4DEngine::U4DLights();
    light->setName("light");
    light->translateTo(3.0,3.0,5.0);
    U4DEngine::U4DVector3n origin(0,0,0);
    
    light->viewInDirection(origin);
    camera->viewInDirection(origin);
    

    addChild(floor);
    addChild(rocket);
    addChild(mountain);
    addChild(mountain2);
    addChild(mountain3);
    addChild(mountain4);
    addChild(planet);
    addChild(meteor1);
    addChild(meteor2);
    addChild(meteor3);

//    debugger->addEntityToDebug(light);
//    addChild(debugger);
    

    
    initLoadingModels();
    
    
}

void Earth::update(double dt){
    
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    camera->followModel(rocket, 0.0, 2.0, 7.0);
    

}

void Earth::action(){
    
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    U4DEngine::U4DLights *light=director->getLight();
    setEntityControlledByController(rocket);
    
}




