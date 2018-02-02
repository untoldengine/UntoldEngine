//
//  GoldAsset.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/6/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "GoldAsset.h"
#include "GoldStateManager.h"
#include "GoldStateInterface.h"
#include "GoldIdleState.h"
#include "GoldEatenState.h"
#include "CommonProtocols.h"

GoldAsset::GoldAsset(){
    
    stateManager=new GoldStateManager(this);
    
    scheduler=new U4DEngine::U4DCallback<GoldAsset>;
    
    timer=new U4DEngine::U4DTimer(scheduler);
}

GoldAsset::~GoldAsset(){
    
    U4DEngine::U4DEntity *parent=getParent();
    
    parent->removeChild(this);
    
    delete scheduler;
    
    delete timer;
    
    delete stateManager;
}

bool GoldAsset::init(const char* uModelName, const char* uBlenderFile){
    
    if (loadModel(uModelName, uBlenderFile)) {
        
        setEnableShadow(false);
    
        initAsPlatform(true);
        
        enableCollisionBehavior();
        
        loadRenderingInformation();
        
        changeState(GoldIdleState::sharedInstance());
        
        return true;
        
    }
    
    return false;
}

void GoldAsset::update(double dt){
    
    stateManager->update(dt);

}

void GoldAsset::changeState(GoldStateInterface* uState){
    
    stateManager->safeChangeState(uState);
    
}

bool GoldAsset::handleMessage(Message &uMsg){
    
    return stateManager->handleMessage(uMsg);
    
}

void GoldAsset::removeFromScenegraph(){
    
    goldAssetParent->removeChild(this);
    
}

void GoldAsset::createParticle(){
    
    goldAssetParent=getParent();
    
    U4DEngine::PARTICLESYSTEMDATA particleData;
    
    particleData.particleStartColor=U4DEngine::U4DVector3n(1.0,1.0,1.0);
    particleData.particleStartColorVariance=U4DEngine::U4DVector3n(0.0,0.0,0.0);
    particleData.particleEndColor=U4DEngine::U4DVector3n(1.0,1.0,1.0);
    
    particleData.particlePositionVariance=U4DEngine::U4DVector3n(0.0,0.0,0.0);
    
    particleData.particleEmitAngle=U4DEngine::U4DVector3n(90.0,0.0,90.0);
    particleData.particleEmitAngleVariance=U4DEngine::U4DVector3n(0.0,0.0,0.0);
    
    particleData.particleSpeed=1.0;
    particleData.particleLife=1.0;
    particleData.texture="particle.png";
    particleData.emitContinuously=false;
    particleData.numberOfParticlesPerEmission=10;
    particleData.emissionRate=0.1;
    particleData.maxNumberOfParticles=10;
    particleData.gravity=U4DEngine::U4DVector3n(0.0,0.0,0.0);
    particleData.particleSystemType=U4DEngine::LINEAREMITTER;
    particleData.enableAdditiveRendering=true;
    particleData.enableNoise=false;
    particleData.particleSize=0.2;

    
    particleSystem=new U4DEngine::U4DParticleSystem();
    particleSystem->init(particleData);
    
    goldAssetParent->addChild(particleSystem,0);
    
    U4DEngine::U4DVector3n pos=getAbsolutePosition();
    
    particleSystem->translateTo(pos);
    
    particleSystem->play();
    
    scheduler->scheduleClassWithMethodAndDelay(this, &GoldAsset::selfDestroy, timer,2.0, false);
    
}

void GoldAsset::selfDestroy(){
    
    goldAssetParent->removeChild(particleSystem);
    
    delete particleSystem;
    
    delete this;
    
}
