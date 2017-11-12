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
    U4DEngine::U4DVector3n cameraPos(0.0,10.0,-15.0);
    
    camera->translateTo(cameraPos);
    
    
    setName("earth");
    setEnableGrid(false);
    
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
    bag=new ModelAsset();

    if(bag->init("bag","blenderscript.u4d")){
        addChild(bag);
    }

    //add barrels
    for(int i=0;i<2;i++){

        std::string name="barrel";
        name+=std::to_string(i);

        barrel[i]=new ModelAsset();

        if(barrel[i]->init(name.c_str(), "blenderscript.u4d")){
            addChild(barrel[i]);
        }

    }

    //add box

    for(int i=0;i<2;i++){

        std::string name="box";
        name+=std::to_string(i);

        box[i]=new ModelAsset();

        if(box[i]->init(name.c_str(), "blenderscript.u4d")){
            addChild(box[i]);
        }

    }

    //add chestgold

    chestgold=new ModelAsset();

    if(chestgold->init("chestgold","blenderscript.u4d")){
        addChild(chestgold);
    }

    //add environment
    for(int i=0;i<12;i++){

        std::string name="environments";
        name+=std::to_string(i);

        environment[i]=new ModelAsset();

        if(environment[i]->init(name.c_str(), "blenderscript.u4d")){
            addChild(environment[i]);
        }

    }

    //add fence

    for(int i=0;i<3;i++){

        std::string name="fence";
        name+=std::to_string(i);

        fence[i]=new ModelAsset();

        if(fence[i]->init(name.c_str(), "blenderscript.u4d")){
            addChild(fence[i]);
        }

    }

    //add house

    for(int i=0;i<6;i++){

        std::string name="house";
        name+=std::to_string(i);

        house[i]=new ModelAsset();

        if(house[i]->init(name.c_str(), "blenderscript.u4d")){
            addChild(house[i]);
        }

    }

    //add lamp
    for(int i=0;i<2;i++){

        std::string name="lamp";
        name+=std::to_string(i);

        lamp[i]=new ModelAsset();

        if(lamp[i]->init(name.c_str(), "blenderscript.u4d")){
            addChild(lamp[i]);
        }

    }

    //add market
    for(int i=0;i<3;i++){

        std::string name="market";
        name+=std::to_string(i);

        market[i]=new ModelAsset();

        if(market[i]->init(name.c_str(), "blenderscript.u4d")){
            addChild(market[i]);
        }

    }


    //add marketstall
    for(int i=0;i<3;i++){

        std::string name="marketstall";
        name+=std::to_string(i);

        marketstall[i]=new ModelAsset();

        if(marketstall[i]->init(name.c_str(), "blenderscript.u4d")){
            addChild(marketstall[i]);
        }

    }

    //add palm
    for(int i=0;i<2;i++){

        std::string name="palm";
        name+=std::to_string(i);

        palm[i]=new ModelAsset();

        if(palm[i]->init(name.c_str(), "blenderscript.u4d")){
            addChild(palm[i]);
        }

    }

    //add stone
    for(int i=0;i<6;i++){

        std::string name="stone";
        name+=std::to_string(i);

        stone[i]=new ModelAsset();

        if(stone[i]->init(name.c_str(), "blenderscript.u4d")){
            addChild(stone[i]);
        }

    }

    //add stonefence
    for(int i=0;i<4;i++){

        std::string name="stonefence";
        name+=std::to_string(i);

        stonefence[i]=new ModelAsset();

        if(stonefence[i]->init(name.c_str(), "blenderscript.u4d")){
            addChild(stonefence[i]);
        }

    }

    //add tile
    for(int i=0;i<3;i++){

        std::string name="tile";
        name+=std::to_string(i);

        tile[i]=new ModelAsset();

        if(tile[i]->init(name.c_str(), "blenderscript.u4d")){
            addChild(tile[i]);
        }

    }

    //add wood
    for(int i=0;i<2;i++){

        std::string name="wood";
        name+=std::to_string(i);

        wood[i]=new ModelAsset();

        if(wood[i]->init(name.c_str(), "blenderscript.u4d")){
            addChild(wood[i]);
        }

    }

    //add metalchest
    metalchest=new ModelAsset();

    if(metalchest->init("metalchest","blenderscript.u4d")){
        addChild(metalchest);
    }

    //add pillar
    pillar=new ModelAsset();

    if(pillar->init("pillar","blenderscript.u4d")){
        addChild(pillar);
    }

    //add well
    well=new ModelAsset();

    if(well->init("well","blenderscript.u4d")){
        addChild(well);
    }

    //add terrain
    terrain=new ModelAsset();

    if(terrain->init("terrain","blenderscript.u4d")){
        addChild(terrain);
    }


    //add gold
//    for(int i=0;i<17;i++){
//
//        std::string name="gold";
//        name+=std::to_string(i);
//
//        gold[i]=new GoldAsset();
//
//        if(gold[i]->init(name.c_str(), "goldscript.u4d")){
//            addChild(gold[i]);
//        }
//
//    }
    
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
    
    delete bag;
    delete chestgold;
    delete metalchest;
    delete pillar;
    delete terrain;
    delete well;
    delete guardian;
    delete points;
    delete fontLoader;
    
    for (int i=0; i<2; i++) {
        delete barrel[i];
    }
    
    for (int i=0; i<2; i++) {
        
        delete box[i];
    }
    
    for (int i=0; i<12; i++) {
        delete environment[i];
    }
    
    for (int i=0; i<3; i++) {
        delete fence[i];
        
    }
    
    for (int i=0; i<6; i++) {
        delete house[i];
        
    }
    
    for (int i=0; i<2; i++) {
        delete lamp[i];
        
    }
    
    for (int i=0; i<3; i++) {
        delete market[i];
        
    }
    
    for (int i=0; i<3; i++) {
        delete marketstall[i];
        
    }
    
    for (int i=0; i<2; i++) {
        delete palm[i];
        
    }
    
    for (int i=0; i<6; i++) {
        delete stone[i];
        
    }
    
    for (int i=0; i<4; i++) {
        delete stonefence[i];
        
    }
    
    for (int i=0; i<3; i++) {
        delete tile[i];
        
    }
    
    for (int i=0; i<2; i++) {
        delete wood[i];
        
    }
    
    for (int i=0; i<17; i++) {
        delete gold[i];
        
    }
}

void Earth::update(double dt){
    
    U4DCamera *camera=U4DCamera::sharedInstance();

    camera->followModel(guardian, 0.0, 10.0, -15.0);
}





