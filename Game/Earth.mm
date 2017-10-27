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
#include "U4DParticleSystem.h"
#include "U4DParticleData.h"
#include "U4DParticleEmitterInterface.h"
#include "U4DParticleEmitterLinear.h"

using namespace U4DEngine;

void Earth::init(){
    
//    U4DEntity *rootnode=new U4DEntity();
//    rootnode->setName("root");
//
//    U4DEntity *node1=new U4DEntity();
//    node1->setName("node1");
//
//    U4DEntity *node2=new U4DEntity();
//    node2->setName("node2");
//
//    U4DEntity *node3=new U4DEntity();
//    node3->setName("node3");
//
//    U4DEntity *node1a=new U4DEntity();
//    node1a->setName("node1a");
//
//    U4DEntity *node1b=new U4DEntity();
//    node1b->setName("node1b");
//
//    U4DEntity *node1c=new U4DEntity();
//    node1c->setName("node1c");
//
//    rootnode->addChild(node1);
//    rootnode->addChild(node2);
//
//
//    node1->addChild(node1a);
//    //node1->addChild(node1b);
//    //node1->addChild(node1c);
//
//    U4DEntity *child=node1->getLastChild();
//
//    while (child!=nullptr) {
//
//        std::cout<<child->getName()<<std::endl;
//
//        child=child->getPrevSibling();
//    }
//
//
//    rootnode->addChild(node3);
    
    //Set camera
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    U4DEngine::U4DVector3n cameraPos(0.0,5.0,-10.0);
    
    camera->translateTo(cameraPos);
    
    
    setName("earth");
    setEnableGrid(true);
    
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
    light->translateTo(0.0,100.0,-100.0);
    
    addChild(light);
    
    camera->viewInDirection(origin);

    //light->viewInDirection(origin);

    
    PARTICLESYSTEMDATA particleData;
    
    particleData.particleStartColor=U4DVector3n(0.2,0.2,0.2);
    //particleData.particleStartColorVariance=U4DVector3n(0.5,0.5,0.5);
    particleData.particleEndColor=U4DVector3n(0.9,0.9,0.9);
    
    particleData.particlePositionVariance=U4DVector3n(0.5,0.0,0.5);
    
    particleData.particleEmitAngle=U4DVector3n(90.0,0.0,90.0);
    particleData.particleEmitAngleVariance=U4DVector3n(0.0,0.0,0.0);
    
    particleData.particleSpeed=1.0;
    particleData.particleLife=2.0;
    particleData.texture="particle.png";
    particleData.emitContinuously=true;
    particleData.numberOfParticlesPerEmission=1.0;
    particleData.emissionRate=0.1;
    particleData.maxNumberOfParticles=200;
    particleData.gravity=U4DVector3n(0.0,0.0,0.0);
    particleData.particleSystemType=LINEAREMITTER;
    particleData.enableNoise=true;
    particleData.noiseDetail=4.0;
    particleData.enableAdditiveRendering=false;
    particleData.particleSize=0.5;
    particleData.torusMajorRadius=5.0;
    particleData.torusMinorRadius=1.0;
    particleData.sphereRadius=5.0;
    
    U4DParticleSystem *particleSystem=new U4DParticleSystem();
    particleSystem->init(particleData);

    particleSystem->translateTo(1.0, 0.0, 0.0);
    //particleSystem->rotateBy(90.0, 0.0, 0.0);
    
    addChild(particleSystem);
    
     GameLogic *gameModel=dynamic_cast<GameLogic*>(getGameModel());
    
    gameModel->setParticleSystem(particleSystem);
    
}

void Earth::update(double dt){
    
    //rotateBy(0.0,1.0,0.0);
}





