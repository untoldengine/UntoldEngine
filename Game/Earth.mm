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
#include "AntiAircraft.h"
#include "GameAsset.h"

using namespace U4DEngine;

void Earth::init(){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    camera->translateBy(0.0,4.0,7.5);
   
    setName("earth");
    
    tank=new Tank();
    tank->init("tankbody", "tankscript.u4d");
    
    tank->setWorld(this);
    
    antiAircraft=new AntiAircraft();
    antiAircraft->init("antiaircraftbase", "antiaircraftscript.u4d");
    
    antiAircraft->setWorld(this);
    
    road=new Floor();
    road->init("road", "blenderscript.u4d");
    
    rubble=new GameAsset();
    rubble->init("rubble", "blenderscript.u4d");
   
    sack1=new GameAsset();
    sack1->init("sack1", "blenderscript.u4d");
    
    sack2=new GameAsset();
    sack2->init("sack2", "blenderscript.u4d");

    house1=new GameAsset();
    house1->init("house1", "blenderscript.u4d");
    

    tire=new GameAsset();
    tire->init("tire", "blenderscript.u4d");
    
    house2=new GameAsset();
    house2->init("house2", "blenderscript.u4d");
    
    landscape=new GameAsset();
    landscape->init("landscape", "blenderscript.u4d");
  
    U4DVector3n origin(0,0,0);
    
    //camera->viewInDirection(origin);

    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(5.0,5.0,5.0);
    light->viewInDirection(origin);
    
    addChild(tank);
    
    addChild(antiAircraft);
    
    addChild(road);
   
    addChild(rubble);
    
    addChild(sack1);
    
    addChild(sack2);
    
    addChild(tire);
    
    addChild(landscape);
    
    addChild(house1);
    
    addChild(house2);
    
    initLoadingModels();
    
}

void Earth::update(double dt){
    
    

}





