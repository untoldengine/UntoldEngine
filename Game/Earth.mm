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
#include "Tree.h"
#include "Cloud.h"

using namespace U4DEngine;

void Earth::init(){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    camera->translateBy(0.0, 3.0, 10.0);
    //camera->rotateTo(0.0,-20.0,0.0);

    //create the floor
    floor=new Floor();
    floor->init("Platform","blenderscript.u4d");
    
    floor2=new Floor();
    floor2->init("Platform2","blenderscript.u4d");
    
    //create the rocket
    rocket=new Rocket();
    rocket->init("Rocket","blenderscript.u4d");
    
    //create mountain
    mountain=new Mountain();
    mountain->init("Mountains", "blenderscript.u4d");
    
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
    
    meteor4=new Meteor();
    meteor4->init("Meteor4", "blenderscript.u4d");
    
    meteor5=new Meteor();
    meteor5->init("Meteor5", "blenderscript.u4d");
    
    tree1=new Tree();
    tree1->init("Tree1", "blenderscript.u4d");
   
    tree2=new Tree();
    tree2->init("Tree2", "blenderscript.u4d");
    
    tree3=new Tree();
    tree3->init("Tree3", "blenderscript.u4d");
    
    tree4=new Tree();
    tree4->init("Tree4", "blenderscript.u4d");
    
    cloud1=new Cloud();
    cloud1->init("Cloud1", "blenderscript.u4d");
    
    cloud2=new Cloud();
    cloud2->init("Cloud2", "blenderscript.u4d");
    
    cloud3=new Cloud();
    cloud3->init("Cloud3", "blenderscript.u4d");
    
    cloud4=new Cloud();
    cloud4->init("Cloud4", "blenderscript.u4d");
    
    cloud5=new Cloud();
    cloud5->init("Cloud5", "blenderscript.u4d");
    
    U4DVector3n origin(0,0,0);
    
    camera->viewInDirection(origin);

    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(5.0,5.0,5.0);
    light->viewInDirection(origin);
    
    addChild(floor);
    
    addChild(rocket);
    addChild(mountain);
    addChild(meteor3);
    addChild(meteor4);
    addChild(meteor5);
    addChild(planet);
    
    
    addChild(floor2);
    addChild(meteor1);
    addChild(meteor2);
    
    addChild(tree1);
    addChild(tree2);
    addChild(tree3);
    addChild(tree4);
    
    addChild(cloud1);
    addChild(cloud2);
    addChild(cloud3);
    
    addChild(cloud4);
    addChild(cloud5);
    
    initLoadingModels();
    
    
}

void Earth::update(double dt){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    camera->followModel(rocket, 0.0, 2.0, 6.0);
    

}

void Earth::action(){
    
    setEntityControlledByController(rocket);
    
}




