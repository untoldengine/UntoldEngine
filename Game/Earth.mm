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
#include "U4DBoundingAABB.h"
#include "U4DMatrix3n.h"

#include "U4DButton.h"
#include "U4DSkyBox.h"
#include "U4DTouches.h"
#include "U4DCamera.h"
#include "U4DControllerInterface.h"

#include "GameController.h"
#include "U4DSprite.h"
#include "U4DSpriteLoader.h"
#include "U4DDigitalAssetLoader.h"
#include "U4DLights.h"
#include "U4DDebugger.h"
#include "Town.h"
#include "U4DConvexHullGenerator.h"

void Earth::init(){
    
    U4DEngine::U4DDebugger *debugger=new U4DEngine::U4DDebugger();
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    camera->translateBy(0.0, 3.0, 10.0);
    //camera->rotateTo(0.0,-20.0,0.0);
    
    setName("earth");
    
    enableGrid(true);
    
    //create our object
    cube=new Town();
    cube->init("GroundFloor",0.0,0.0,0.0);
    cube->setName("cube");
    cube->setShader("simpleShader");
    //cube->setAsGround(true);
    //Apply the collision engine to the object
    //cube->enableCollision();
    //cube->setMass(1.0);
    //cube->setCoefficientOfRestitution(0.7);
    
    //cube->setNarrowPhaseBoundingVolumeVisibility(true);
    
    cube2=new Town();
    cube2->init("Cube",0.0,0.0,0.0);
    cube2->setShader("simpleShader");
    cube2->setName("cube2");
    
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
    enableShadows();
    
    
    U4DEngine::U4DLights *light=new U4DEngine::U4DLights();
    light->setName("light");
    light->translateTo(3.0,3.0,3.0);
    U4DEngine::U4DVector3n origin(0,0,0);
    
    light->viewInDirection(origin);
   
    
    
    //addChild(cube3);
    addChild(cube);
    addChild(cube2);
    addChild(light);

    debugger->addEntityToDebug(light);
    //addChild(debugger);
    
    
    initLoadingModels();
    
    
}

void Earth::update(double dt){
    
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    //camera->followModel(cube2, 0.0, 2.0, 7.0);
    

}

void Earth::action(){
    
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    U4DEngine::U4DLights *light=director->getLight();
    setEntityControlledByController(cube2);
    
}




