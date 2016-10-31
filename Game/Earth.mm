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
    camera->translateBy(0.0, 3.5, 12.0);
   
    //create character
    robot=new MyCharacter();
    robot->init("robot", "characterscript.u4d");
    
    //create the floor
    floor=new Floor();
    floor->init("platform","blenderscript.u4d");
    
    //create rock
    rock=new Rock();
    rock->init("rock","blenderscript.u4d");
    
    //create tree
    tree=new GameAsset();
    tree->init("tree","blenderscript.u4d");
    
    //create clouds
    cloud=new GameAsset();
    cloud->init("cloud","blenderscript.u4d");
    
    cloud2=new GameAsset();
    cloud2->init("cloud2","blenderscript.u4d");
    
    U4DVector3n origin(0,0,0);
    
    camera->viewInDirection(origin);

    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(5.0,5.0,5.0);
    light->viewInDirection(origin);
    
    addChild(robot);
    
    addChild(floor);
    
    addChild(rock);
    
    addChild(tree);
    
    addChild(cloud2);
    
    addChild(cloud);
    
    initLoadingModels();
    
    
}

void Earth::update(double dt){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    camera->followModel(robot, 0.0, 2.0, 12.0);
    

}





