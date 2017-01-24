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
#include "GameAsset.h"
#include "Rock.h"

using namespace U4DEngine;

void Earth::init(){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    camera->translateBy(0.0, 2.0, 3.5);
    
    setName("earth");
    
    enableShadows();
    
    //create character
    rocket=new MyCharacter();
    rocket->init("rocket", "characterscript.u4d");
    
    //create rock
    rock1=new Rock();
    rock1->init("rock1","blenderscript.u4d");
    
    rock2=new Rock();
    rock2->init("rock2","blenderscript.u4d");

    rock3=new Rock();
    rock3->init("rock3","blenderscript.u4d");
    
//
//    planetEarth=new GameAsset();
//    planetEarth->init("earth", "blenderscript.u4d");
//    
//    planetSaturn=new GameAsset();
//    planetSaturn->init("planet", "blenderscript.u4d");
//    
//    belt=new GameAsset();
//    belt->init("belt", "blenderscript.u4d");
//    
//    land=new GameAsset();
//    land->init("land", "blenderscript.u4d");
    
//
//    //create the floor
//    floor=new Floor();
//    floor->init("platform","blenderscript.u4d");
//    

    
    //create tree
//    tree=new GameAsset();
//    tree->init("tree","blenderscript.u4d");
    
//    //create clouds
//    cloud=new GameAsset();
//    cloud->init("cloud","blenderscript.u4d");
//    
//    cloud2=new GameAsset();
//    cloud2->init("cloud2","blenderscript.u4d");
    
    U4DVector3n origin(0,0,0);
    
    camera->viewInDirection(origin);

    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(5.0,5.0,5.0);
    light->viewInDirection(origin);
    
    addChild(rocket);
    
    addChild(rock1);
    
    addChild(rock2);
    
    addChild(rock3);
    
//    addChild(planetEarth);
//    
//    addChild(planetSaturn);
//    
//    addChild(belt);
//    
//    addChild(land);
    
    
    
//    addChild(floor);
//    
//
    
//    addChild(tree);
    
//    addChild(cloud2);
//    
//    addChild(cloud);
    

    
}

void Earth::update(double dt){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    camera->followModel(rocket, 0.0, 2.0, 3.5);
    

}





