//
//  ModelAsset.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/23/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "ModelAsset.h"

ModelAsset::ModelAsset(){
    
    
}

ModelAsset::~ModelAsset(){
    
    //remove the particle system from the graph before deleting it
    U4DEngine::U4DEntity *parent=getParent();
    
    parent->removeChild(particleSystem);
    delete particleSystem;
    
    parent->removeChild(this);
    
    
}

void ModelAsset::init(const char* uModelName, const char* uBlenderFile){
    
    if (loadModel(uModelName, uBlenderFile)) {
        
        setEnableShadow(false);
        
        loadRenderingInformation();
    }
}

void ModelAsset::update(double dt){
    
}

void ModelAsset::loadParticleSystemInfo(U4DEngine::PARTICLESYSTEMDATA &uParticleSystemData){

    particleSystemData=uParticleSystemData;
    
}

void ModelAsset::startParticleSystem(){
    
    particleSystem=new U4DEngine::U4DParticleSystem();
    
    //particleSystem->rotateBy(90.0, 0.0, 0.0);
    
    U4DEngine::U4DVector3n pos=getAbsolutePosition();
    particleSystem->translateTo(pos);
    
    
    particleSystem->init(particleSystemData);
    
    //load it into the graph
    
    U4DEngine::U4DEntity *parent=getParent();
    
    parent->addChild(particleSystem);
    
    //remove model from the graph
    
    parent->removeChild(this);
    
}

