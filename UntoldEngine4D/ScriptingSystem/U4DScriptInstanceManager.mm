//
//  U4DScriptInstanceManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/9/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DScriptInstanceManager.h"

namespace U4DEngine{

U4DScriptInstanceManager* U4DScriptInstanceManager::instance=0;

U4DScriptInstanceManager* U4DScriptInstanceManager::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DScriptInstanceManager();
    }

    return instance;
}

U4DScriptInstanceManager::U4DScriptInstanceManager(){
     
        
    }

U4DScriptInstanceManager::~U4DScriptInstanceManager(){
        
    }

void U4DScriptInstanceManager::loadModelScriptInstance(U4DModel *uModel, gravity_instance_t *uGravityInstance){
    
    modelInstanceMap.insert(std::make_pair(uModel->getEntityId(), uModel));
    scriptModelInstanceMap.insert(std::make_pair(uModel->getEntityId(),uGravityInstance));
    
}

gravity_instance_t *U4DScriptInstanceManager::getModelScriptInstance(uint uEntityID){
    
    std::map<uint,gravity_instance_t*>::iterator it=scriptModelInstanceMap.find(uEntityID);
    gravity_instance_t* gravityModelInstance=nullptr;
    
    if (it != scriptModelInstanceMap.end()) {
        gravityModelInstance=scriptModelInstanceMap.find(uEntityID)->second;
    }
    
    return gravityModelInstance;
}

bool U4DScriptInstanceManager::modelScriptInstanceExist(uint uEntityID){
    
    std::map<uint,gravity_instance_t*>::iterator it=scriptModelInstanceMap.find(uEntityID);
    
    bool scriptPresent=false;
    
    if (it != scriptModelInstanceMap.end()) {
        scriptPresent=true;
    }
    
    return scriptPresent;
    
}

U4DModel *U4DScriptInstanceManager::getModel(uint uEntityID){
    
    std::map<uint,U4DModel*>::iterator it=modelInstanceMap.find(uEntityID);
    U4DModel* modelInstance=nullptr;
    
    if (it != modelInstanceMap.end()) {
        modelInstance=modelInstanceMap.find(uEntityID)->second;
    }
    
    return modelInstance;
    
}

void U4DScriptInstanceManager::removeModelScriptInstance(uint uEntityID){
    
    std::map<uint,gravity_instance_t*>::iterator it=scriptModelInstanceMap.find(uEntityID);
    
    scriptModelInstanceMap.erase(it);
    
    std::map<uint,U4DModel*>::iterator mit=modelInstanceMap.find(uEntityID);
    
    modelInstanceMap.erase(mit);
}

void U4DScriptInstanceManager::removeAllScriptInstanceModels(){
    
//    U4DScriptManager *scriptManager=U4DScriptManager::sharedInstance();
//
//    std::map<uint,gravity_instance_t*>::iterator it;
//
//    for(it=scriptModelInstanceMap.begin();it!=scriptModelInstanceMap.end();it++){
//
//        gravity_instance_t *gravityIntance=it->second;
//
//        scriptManager->modelFree(scriptManager->vm, (gravity_object_t*)gravityIntance);
//
//    }
//
//    scriptModelInstanceMap.clear();
}





}
