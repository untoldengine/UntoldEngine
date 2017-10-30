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

    PARTICLESYSTEMDATA dustParticleData;
    
    dustParticleData.particleStartColor=U4DVector3n(0.2,0.2,0.2);
    //dustParticleData.particleStartColorVariance=U4DVector3n(0.5,0.5,0.5);
    dustParticleData.particleEndColor=U4DVector3n(0.9,0.9,0.9);
    
    dustParticleData.particlePositionVariance=U4DVector3n(0.5,0.5,0.5);
    
    dustParticleData.particleEmitAngle=U4DVector3n(90.0,0.0,90.0);
    dustParticleData.particleEmitAngleVariance=U4DVector3n(0.0,0.0,0.0);
    
    dustParticleData.particleSpeed=2.0;
    dustParticleData.particleLife=2.0;
    dustParticleData.texture="particle.png";
    dustParticleData.emitContinuously=true;
    dustParticleData.numberOfParticlesPerEmission=1.0;
    dustParticleData.emissionRate=0.1;
    dustParticleData.maxNumberOfParticles=200;
    dustParticleData.gravity=U4DVector3n(0.0,0.0,0.0);
    dustParticleData.particleSystemType=LINEAREMITTER;
    dustParticleData.enableNoise=true;
    dustParticleData.noiseDetail=4.0;
    dustParticleData.enableAdditiveRendering=false;
    dustParticleData.particleSize=1.0;
    
    
    U4DParticleSystem *particleSystem1=new U4DParticleSystem();
    particleSystem1->init(dustParticleData);
    
    addChild(particleSystem1);
    
    PARTICLESYSTEMDATA particleData2;

    particleData2.particleStartColor=U4DVector3n(1.0,0.0,0.0);
    //particleData2.particleStartColorVariance=U4DVector3n(0.1,0.1,0.1);
    particleData2.particleEndColor=U4DVector3n(0.0,1.0,1.0);

    particleData2.particleSpeed=1.0;
    particleData2.particleLife=3.5;
    particleData2.texture="particle.png";
    particleData2.emitContinuously=false;
    particleData2.numberOfParticlesPerEmission=200.0;
    particleData2.emissionRate=0.1;
    particleData2.maxNumberOfParticles=200;
    particleData2.gravity=U4DVector3n(0.0,0.0,0.0);
    particleData2.particleSystemType=TORUSEMITTER;
    particleData2.enableNoise=false;
    particleData2.enableAdditiveRendering=true;
    particleData2.particleSize=1.0;
    particleData2.torusMajorRadius=15.0;
    particleData2.torusMinorRadius=5.0;

    U4DParticleSystem *particleSystem2=new U4DParticleSystem();
    particleSystem2->init(particleData2);
    
    
    addChild(particleSystem2);
    
    
    PARTICLESYSTEMDATA particleData3;
    
    particleData3.particleStartColor=U4DVector3n(0.0,0.0,1.0);
    //particleData3.particleStartColorVariance=U4DVector3n(0.1,0.1,0.1);
    particleData3.particleEndColor=U4DVector3n(1.0,0.0,0.0);
    
    particleData3.particleSpeed=2.0;
    particleData3.particleLife=3.0;
    particleData3.texture="particle.png";
    particleData3.emitContinuously=false;
    particleData3.numberOfParticlesPerEmission=200.0;
    particleData3.emissionRate=0.1;
    particleData3.maxNumberOfParticles=200;
    particleData3.gravity=U4DVector3n(0.0,0.0,0.0);
    particleData3.particleSystemType=SPHERICALEMITTER;
    particleData3.enableNoise=false;
    particleData3.enableAdditiveRendering=true;
    particleData3.particleSize=1.0;
    particleData3.sphereRadius=5.0;
    
    U4DParticleSystem *particleSystem3=new U4DParticleSystem();
    particleSystem3->init(particleData3);
    
    
    addChild(particleSystem3);
    
    
    PARTICLESYSTEMDATA particleData4;
    
    particleData4.particleStartColor=U4DVector3n(0.2,0.2,0.2);
    particleData4.particleStartColorVariance=U4DVector3n(0.1,0.1,0.1);
    particleData4.particleEndColor=U4DVector3n(0.0,0.0,1.0);
    
    particleData4.particlePositionVariance=U4DVector3n(0.0,0.0,0.0);
    
    particleData4.particleEmitAngle=U4DVector3n(90.0,0.0,90.0);
    particleData4.particleEmitAngleVariance=U4DVector3n(40.0,0.0,30.0);
    
    particleData4.particleSpeed=6.0;
    particleData4.particleLife=2.0;
    particleData4.texture="particle.png";
    particleData4.emitContinuously=true;
    particleData4.numberOfParticlesPerEmission=10.0;
    particleData4.emissionRate=0.1;
    particleData4.maxNumberOfParticles=200;
    particleData4.gravity=U4DVector3n(0.0,-5.0,0.0);
    particleData4.particleSystemType=LINEAREMITTER;
    particleData4.enableAdditiveRendering=true;
    particleData4.enableNoise=false;
    particleData4.particleSize=0.5;
    
    
    U4DParticleSystem *particleSystem4=new U4DParticleSystem();
    particleSystem4->init(particleData4);
    
    addChild(particleSystem4);
    
    PARTICLESYSTEMDATA particleData5;
    
    particleData5.particleStartColor=U4DVector3n(1.0,1.0,1.0);
    //particleData5.particleStartColorVariance=U4DVector3n(0.5,0.5,0.5);
    particleData5.particleEndColor=U4DVector3n(1.0,1.0,1.0);
    
    particleData5.particlePositionVariance=U4DVector3n(20.0,0.0,20.0);
    
    particleData5.particleEmitAngle=U4DVector3n(90.0,0.0,90.0);
    particleData5.particleEmitAngleVariance=U4DVector3n(0.0,0.0,0.0);
    
    particleData5.particleSpeed=0.0;
    particleData5.particleLife=10.0;
    particleData5.texture="particle.png";
    particleData5.emitContinuously=true;
    particleData5.numberOfParticlesPerEmission=10.0;
    particleData5.emissionRate=0.5;
    particleData5.maxNumberOfParticles=200;
    particleData5.gravity=U4DVector3n(0.0,-5.0,0.0);
    particleData5.particleSystemType=LINEAREMITTER;
    particleData5.enableAdditiveRendering=true;
    particleData5.enableNoise=false;
    particleData5.particleSize=0.3;
    
    
    U4DParticleSystem *particleSystem5=new U4DParticleSystem();
    particleSystem5->init(particleData5);
    
    addChild(particleSystem5);
    
    particleSystem1->translateTo(-5.0, 0.0, 1.0);
    
    particleSystem2->translateTo(0.0, 0.0, 1.0);
    
    particleSystem2->translateTo(0.0, 0.5, 0.0);
    particleSystem2->rotateTo(90.0, 0.0, 0.0);
    
    particleSystem3->translateTo(0.0, 3.0, 0.0);
    
    particleSystem5->translateTo(0.0, 15.0, 0.0);
    
    GameLogic *gameModel=dynamic_cast<GameLogic*>(getGameModel());

    gameModel->addParticleSystem(particleSystem1);
    gameModel->addParticleSystem(particleSystem2);
    gameModel->addParticleSystem(particleSystem3);
    gameModel->addParticleSystem(particleSystem4);
    gameModel->addParticleSystem(particleSystem5);
}

void Earth::update(double dt){
    
    //rotateBy(0.0,1.0,0.0);
    
    U4DLights *light=U4DLights::sharedInstance();
    U4DCamera *camera=U4DCamera::sharedInstance();
    
    U4DVector3n cameraPos=camera->getAbsolutePosition();
    
    //light->translateTo(cameraPos);
}





