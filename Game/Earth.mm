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

#include "U4DParticleSystem.h"
#include "U4DParticleData.h"
#include "U4DParticleEmitterInterface.h"
#include "U4DParticleEmitterLinear.h"

using namespace U4DEngine;

void Earth::init(){
    
    //Set camera
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    U4DEngine::U4DVector3n cameraPos(0.0,10.0,-40.0);
    
    camera->translateTo(cameraPos);
    
    
    setName("earth");
    setEnableGrid(false);
    
    U4DDirector *director=U4DDirector::sharedInstance();
    
    director->setWorld(this);
    
    //compute perspective space
    U4DEngine::U4DMatrix4n perspectiveSpace=director->computePerspectiveSpace(30.0f, director->getAspect(), 0.01f, 100.0f);
    director->setPerspectiveSpace(perspectiveSpace);
    
    //compute orthographic shadow space
    U4DEngine::U4DMatrix4n orthographicShadowSpace=director->computeOrthographicSpace(-100.0f, 100.0f, -100.0f, 100.0f, -100.0f, 100.0f);
    director->setOrthographicShadowSpace(orthographicShadowSpace);
    
    U4DVector3n origin(0,0,0);

    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(0.0,50.0,-50.0);
    U4DVector3n white(1.0,1.0,1.0);
    light->setDiffuseColor(white);
    addChild(light);
    
    camera->viewInDirection(origin);

    light->viewInDirection(origin);
    
    //load bonfire
    bonfire=new GameAsset();
    bonfire->init("bonfire", "blenderscript.u4d");

    addChild(bonfire);

    PARTICLESYSTEMDATA particleData;

    particleData.particleStartColor=U4DVector3n(0.0,0.0,0.0);
    //particleData.particleStartColorVariance=U4DVector3n(0.5,0.5,0.5);
    particleData.particleEndColor=U4DVector3n(0.9,0.9,0.9);

    particleData.particlePositionVariance=U4DVector3n(0.0,0.0,0.0);

    particleData.particleEmitAngle=U4DVector3n(90.0,0.0,90.0);
    particleData.particleEmitAngleVariance=U4DVector3n(0.0,0.0,0.0);

    particleData.particleSpeed=0.3;
    particleData.particleLife=2.0;
    particleData.texture="particle.png";
    particleData.emitContinuously=true;
    particleData.numberOfParticlesPerEmission=1.0;
    particleData.emissionRate=0.7;
    particleData.maxNumberOfParticles=200;
    particleData.gravity=U4DVector3n(0.0,0.0,0.0);
    particleData.particleSystemType=LINEAREMITTER;
    particleData.enableNoise=true;
    particleData.noiseDetail=4.0;
    particleData.enableAdditiveRendering=false;
    particleData.particleSize=0.3;
    particleData.torusMajorRadius=5.0;
    particleData.torusMinorRadius=1.0;
    particleData.sphereRadius=5.0;

    U4DParticleSystem *particleSystem=new U4DParticleSystem();
    particleSystem->init(particleData);

    U4DVector3n smokepos=bonfire->getAbsolutePosition();
    smokepos.y+=0.1;
    particleSystem->translateTo(smokepos);

    addChild(particleSystem);

    //load land
    land=new GameAsset();
    land->init("land","blenderscript.u4d");

    //load lake
    lake=new GameAsset();
    lake->init("lake", "blenderscript.u4d");


    //load raft
    raft=new GameAsset();
    raft->init("raft", "blenderscript.u4d");

    //load tent
    tent=new GameAsset();
    tent->init("tent", "blenderscript.u4d");

    addChild(land);
    addChild(lake);

    addChild(raft);
    addChild(tent);

    //load trees
    for(int i=0;i<34;i++){

        std::string name="tree";
        name+=std::to_string(i);

        tree[i]=new GameAsset();

        if(tree[i]->init(name.c_str(), "blenderscript.u4d")){

            addChild(tree[i]);

        }

    }

    //load beet
    for(int i=0;i<5;i++){

        std::string name="beet";
        name+=std::to_string(i);

        beet[i]=new GameAsset();

        if(beet[i]->init(name.c_str(), "blenderscript.u4d")){

            addChild(beet[i]);

        }

    }

    //load cloud
    for(int i=0;i<5;i++){

        std::string name="cloud";
        name+=std::to_string(i);

        cloud[i]=new GameAsset();

        if(cloud[i]->init(name.c_str(), "blenderscript.u4d")){

            addChild(cloud[i]);

        }

    }

    //load carrot
    for(int i=0;i<9;i++){

        std::string name="carrot";
        name+=std::to_string(i);

        carrot[i]=new GameAsset();

        if(carrot[i]->init(name.c_str(), "blenderscript.u4d")){

            addChild(carrot[i]);

        }

    }

    //load grass
    for(int i=0;i<16;i++){

        std::string name="grass";
        name+=std::to_string(i);

        grass[i]=new GameAsset();

        if(grass[i]->init(name.c_str(), "blenderscript.u4d")){

            addChild(grass[i]);

        }

    }

    //load punkin
    for(int i=0;i<4;i++){

        std::string name="pumpkin";
        name+=std::to_string(i);

        pumpkin[i]=new GameAsset();

        if(pumpkin[i]->init(name.c_str(), "blenderscript.u4d")){

            addChild(pumpkin[i]);

        }

    }

    //load wood
    for(int i=0;i<3;i++){

        std::string name="wood";
        name+=std::to_string(i);

        wood[i]=new GameAsset();

        if(wood[i]->init(name.c_str(), "blenderscript.u4d")){

            addChild(wood[i]);

        }

    }
    
    director->setPolycount(5000);
    
    U4DVector3n gravity(0.0,-7.0,0.0);
    
    //load baloon with torus system
    bomb0=new ModelAsset();
    bomb0->init("bomb", "blenderscript.u4d");
    bomb0->setGravity(gravity);
    bomb0->enableKineticsBehavior();
    PARTICLESYSTEMDATA particleTorusNoiseData;
    
    particleTorusNoiseData.particleStartColor=U4DVector3n(1.0,0.0,0.0);
    particleTorusNoiseData.particleStartColorVariance=U4DVector3n(0.1,0.1,0.1);
    particleTorusNoiseData.particleEndColor=U4DVector3n(1.0,0.0,1.0);
    
    particleTorusNoiseData.particlePositionVariance=U4DVector3n(0.0,0.0,0.0);
    
    particleTorusNoiseData.particleEmitAngle=U4DVector3n(90.0,0.0,90.0);
    particleTorusNoiseData.particleEmitAngleVariance=U4DVector3n(0.0,0.0,0.0);
    
    particleTorusNoiseData.particleSpeed=5.0;
    particleTorusNoiseData.particleLife=2.0;
    particleTorusNoiseData.texture="particle.png";
    particleTorusNoiseData.emitContinuously=false;
    particleTorusNoiseData.numberOfParticlesPerEmission=200.0;
    particleTorusNoiseData.emissionRate=0.1;
    particleTorusNoiseData.maxNumberOfParticles=200;
    particleTorusNoiseData.gravity=U4DVector3n(0.0,0.0,0.0);
    particleTorusNoiseData.particleSystemType=SPHERICALEMITTER;
    particleTorusNoiseData.enableNoise=true;
    particleTorusNoiseData.enableAdditiveRendering=true;
    particleTorusNoiseData.particleSize=0.5;
    particleTorusNoiseData.torusMajorRadius=5.0;
    particleTorusNoiseData.torusMinorRadius=1.0;
    particleTorusNoiseData.sphereRadius=5.0;
    
    bomb0->loadParticleSystemInfo(particleTorusNoiseData);
    
    addChild(bomb0);

    GameLogic *gameModel=dynamic_cast<GameLogic*>(getGameModel());

    gameModel->setModelAsset(bomb0);
    
}

void Earth::update(double dt){
    
    //rotateBy(0.0,1.0,0.0);
    
    U4DLights *light=U4DLights::sharedInstance();
    U4DCamera *camera=U4DCamera::sharedInstance();
    
    U4DVector3n cameraPos=camera->getAbsolutePosition();
    
    //light->translateTo(cameraPos);
}





