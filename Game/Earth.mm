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
#include "U4DCamera.h"
#include "U4DControllerInterface.h"

#include "GameController.h"
#include "U4DLights.h"
#include "U4DLogger.h"


#include "GameLogic.h"

#include "GameAsset.h"
#include "ModelAsset.h"
#include "GuardianModel.h"
#include "GoldAsset.h"

#include "U4DParticleSystem.h"
#include "U4DParticleData.h"
#include "U4DParticleEmitterInterface.h"
#include "U4DParticleEmitterLinear.h"
#include "U4DSpriteLoader.h"
#include "U4DSprite.h"
#include "U4DSpriteAnimation.h"

#include "U4DFontLoader.h"
#include "U4DText.h"

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
    
    //compute perspective space
    U4DEngine::U4DMatrix4n perspectiveSpace=director->computePerspectiveSpace(30.0f, director->getAspect(), 0.01f, 100.0f);
    director->setPerspectiveSpace(perspectiveSpace);
    
    //compute orthographic shadow space
    U4DEngine::U4DMatrix4n orthographicShadowSpace=director->computeOrthographicShadowSpace(-30.0f, 30.0f, -30.0f, 30.0f, -30.0f, 30.0f);
    director->setOrthographicShadowSpace(orthographicShadowSpace);
    
    U4DVector3n origin(0,0,0);

    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(10.0,10.0,-10.0);
    U4DEngine::U4DVector3n diffuse(0.5,0.5,0.5);
    U4DEngine::U4DVector3n specular(0.1,0.1,0.1);
    light->setDiffuseColor(diffuse);
    light->setSpecularColor(specular);
    addChild(light);
    
    camera->viewInDirection(origin);

    light->viewInDirection(origin);
    
    //add bag


    //add gold
    for(int i=0;i<5;i++){

        std::string name="Cube";
        name+=std::to_string(i);

        cube[i]=new ModelAsset();

        if(cube[i]->init(name.c_str(), "blenderscript.u4d")){
            addChild(cube[i]);
        }
        //cube[i]->rotateTo(30.0,20.0,-40.0);
        cube[i]->enableKineticsBehavior();
    }
    

//    cube0=new ModelAsset();
//
//    if(cube0->init("Cube0", "blenderscript.u4d")){
//        addChild(cube0);
//    }

    //cube0->enableKineticsBehavior();
//    cube0->rotateTo(30.0,20.0,-40.0);
    //cube0->translateBy(2.9, 0.0, -3.2);
    
    terrain=new GameAsset();
    
    if (terrain->init("terrain","blenderscript.u4d")) {
        
        addChild(terrain);
        
    }
    
    //add character
    guardian=new GuardianModel();

    if(guardian->init("guardian","guardianscript.u4d")){
        addChild(guardian);
    }

    guardian->translateBy(0.0, 0.0, -4.0);
    
    //get game model pointer
    GameLogic *gameModel=dynamic_cast<GameLogic*>(getGameModel());
    
   gameModel->setGuardian(guardian);
    
    //Load the font loader
    fontLoader=new U4DFontLoader();
    
    fontLoader->loadFontAssetFile("myFont.xml", "myFont.png");
    
    //create a text object
    points=new U4DEngine::U4DText(fontLoader,20);
    
    points->setText("Points: 0");
    points->translateTo(0.4,0.8,0.0);
    addChild(points,0);
    //note make sure to add the text before any other objects in the scenegraph
    
    gameModel->setText(points);
}

Earth::~Earth(){
    
   
}

void Earth::update(double dt){
    //rotateBy(0.0, 0.5, 0.0);
    U4DCamera *camera=U4DCamera::sharedInstance();
    
    //camera->followModel(guardian, 0.0, 2.0, -10.0);
}





