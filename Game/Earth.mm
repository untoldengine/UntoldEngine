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
#include "U4DLights.h"
#include "U4DLogger.h"


#include "GameLogic.h"
#include "GameAsset.h"
#include "ModelAsset.h"
#include "SoccerPlayer.h"

using namespace U4DEngine;

void Earth::init(){
    
    //Set camera
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    U4DEngine::U4DVector3n cameraPos(0.0,10.0,-20.0);
    
    camera->translateTo(cameraPos);
    
    
    setName("earth");
    setEnableGrid(true);
    
    U4DDirector *director=U4DDirector::sharedInstance();
    
    director->setWorld(this);
    
    U4DVector3n origin(0,0,0);

    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(0.0,10.2,1.0);
    
    addChild(light);
    
    
    camera->viewInDirection(origin);
    light->viewInDirection(origin);
    
    
    house1=new ModelAsset();
    house1->init("small_house_1", "cityscript.u4d","small_house_normal.png");
    
    
    addChild(house1);

    littleMansion=new ModelAsset();
    littleMansion->init("little_mansion", "cityscript.u4d","little_mansion_NRM.png");
    
    addChild(littleMansion);
  
    
    house2=new ModelAsset();
    house2->init("small_house_2", "cityscript.u4d","small_house_02_NRM.png");
    
    addChild(house2);
    
    fort=new ModelAsset();
    fort->init("fort", "cityscript.u4d", "fort_normal.png");
    
    addChild(fort);
    
    
    
    
    skybox=new U4DEngine::U4DSkybox();
    skybox->initSkyBox(50.0, "RightImage.png","LeftImage.png", "TopImage.png","BottomImage.png", "FrontImage.png", "BackImage.png");
    
    //addChild(skybox);
    
    
    ground=new GameAsset();
    ground->init("ground","cityscript.u4d");
    addChild(ground);
    
    
    
    player=new SoccerPlayer();
    player->init("guardian","player.u4d","armor_NRM.png");
    
    addChild(player);
    
    player->translateTo(0.0, 1.8, 0.0);
    //player->playAnimation();
    
    translateTo(0.0, -1.0, 0);
    
}

void Earth::update(double dt){
    
    player->rotateBy(0.0, 1.0, 0.0);
    
}





