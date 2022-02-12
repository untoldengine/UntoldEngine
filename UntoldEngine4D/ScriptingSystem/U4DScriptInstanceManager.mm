//
//  U4DScriptInstanceManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/10/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DScriptInstanceManager.h"
#include "U4DScriptManager.h"

namespace U4DEngine{

U4DScriptInstanceManager* U4DScriptInstanceManager::instance=0;

U4DScriptInstanceManager* U4DScriptInstanceManager::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DScriptInstanceManager();
    }

    return instance;
}

U4DScriptInstanceManager::U4DScriptInstanceManager():modelInstanceIndex(1){
     
        
    }

U4DScriptInstanceManager::~U4DScriptInstanceManager(){
        
    }

void U4DScriptInstanceManager::loadModelScriptInstance(U4DModel *uModel, gravity_instance_t *uGravityInstance){
    
    uModel->setScriptID(modelInstanceIndex);
    
    scriptModelInstanceMap.insert(std::make_pair(modelInstanceIndex,uGravityInstance));
    
    modelInstanceIndex++;
    
}

gravity_instance_t *U4DScriptInstanceManager::getModelScriptInstance(int uScriptID){
    
    std::map<int,gravity_instance_t*>::iterator it=scriptModelInstanceMap.find(uScriptID);
    gravity_instance_t* gravityModelInstance=nullptr;
    
    if (it != scriptModelInstanceMap.end()) {
        gravityModelInstance=scriptModelInstanceMap.find(uScriptID)->second;
    }
    
    return gravityModelInstance;
}

bool U4DScriptInstanceManager::modelScriptInstanceExist(int uScriptID){
    
    std::map<int,gravity_instance_t*>::iterator it=scriptModelInstanceMap.find(uScriptID);
    
    bool scriptPresent=false;
    
    if (it != scriptModelInstanceMap.end()) {
        scriptPresent=true;
    }
    
    return scriptPresent;
    
}

void U4DScriptInstanceManager::loadAnimationScriptInstance(U4DAnimation *uAnimation, gravity_instance_t *uGravityInstance){
    
    scriptAnimationInstanceMap.insert(std::make_pair(uAnimation,uGravityInstance));
}

gravity_instance_t *U4DScriptInstanceManager::getAnimationScriptInstance(U4DAnimation *uAnimation){
    
    std::map<U4DAnimation*,gravity_instance_t*>::iterator it=scriptAnimationInstanceMap.find(uAnimation);
    
    gravity_instance_t* gravityAnimationInstance=nullptr;
    
    if (it != scriptAnimationInstanceMap.end()) {
        gravityAnimationInstance=scriptAnimationInstanceMap.find(uAnimation)->second;
    }
    
    return gravityAnimationInstance;
    
}

void U4DScriptInstanceManager::loadAnimManagerScriptInstance(U4DAnimationManager *uAnimationManager, gravity_instance_t *uGravityInstance){
    
    scriptAnimManagerInstanceMap.insert(std::make_pair(uAnimationManager,uGravityInstance));
}

gravity_instance_t *U4DScriptInstanceManager::getAnimManagerScriptInstance(U4DAnimationManager *uAnimationManager){
    
    std::map<U4DAnimationManager*,gravity_instance_t*>::iterator it=scriptAnimManagerInstanceMap.find(uAnimationManager);
    
    gravity_instance_t* gravityAnimManagerInstance=nullptr;
    
    if (it != scriptAnimManagerInstanceMap.end()) {
        gravityAnimManagerInstance=scriptAnimManagerInstanceMap.find(uAnimationManager)->second;
    }
    
    return gravityAnimManagerInstance;
    
}

void U4DScriptInstanceManager::loadDynamicActionScriptInstance(U4DDynamicAction *uDynamicAction, gravity_instance_t *uGravityInstance){
    
    scriptDynamicActionInstanceMap.insert(std::make_pair(uDynamicAction,uGravityInstance));
}

gravity_instance_t *U4DScriptInstanceManager::getDynamicActionScriptInstance(U4DDynamicAction *uDynamicAction){
    
    std::map<U4DDynamicAction*,gravity_instance_t*>::iterator it=scriptDynamicActionInstanceMap.find(uDynamicAction);
    
    gravity_instance_t* gravityDynamicActionInstance=nullptr;
    
    if (it != scriptDynamicActionInstanceMap.end()) {
        gravityDynamicActionInstance=scriptDynamicActionInstanceMap.find(uDynamicAction)->second;
    }
    
    return gravityDynamicActionInstance;
    
}

void U4DScriptInstanceManager::removeAllScriptInstanceAnimations(){
    
    U4DScriptManager *scriptManager=U4DScriptManager::sharedInstance();
    
    std::map<U4DAnimation *, gravity_instance_t *>::iterator it;
    
    for(it=scriptAnimationInstanceMap.begin();it!=scriptAnimationInstanceMap.end();it++){
        
        //U4DAnimation *animation=it->first;
        gravity_instance_t *gravityInstance=it->second;
        
        scriptManager->animationFree(scriptManager->vm, (gravity_object_t*)gravityInstance);
    }
    
    scriptAnimationInstanceMap.clear();
    
}

void U4DScriptInstanceManager::removeModelScriptInstance(int uScriptID){
    
    std::map<int,gravity_instance_t*>::iterator it=scriptModelInstanceMap.find(uScriptID);
    
    scriptModelInstanceMap.erase(it);
}

void U4DScriptInstanceManager::removeAllScriptInstanceModels(){
    
    U4DScriptManager *scriptManager=U4DScriptManager::sharedInstance();
    
    std::map<int,gravity_instance_t*>::iterator it;
    
    for(it=scriptModelInstanceMap.begin();it!=scriptModelInstanceMap.end();it++){
        
        gravity_instance_t *gravityIntance=it->second;
        
        scriptManager->modelFree(scriptManager->vm, (gravity_object_t*)gravityIntance);
        
    }
    
    scriptModelInstanceMap.clear();
}

void U4DScriptInstanceManager::removeAllScriptInstanceDynamicActions(){
    
    U4DScriptManager *scriptManager=U4DScriptManager::sharedInstance();
    
    std::map<U4DDynamicAction*,gravity_instance_t*>::iterator it;
    
    for(it=scriptDynamicActionInstanceMap.begin();it!=scriptDynamicActionInstanceMap.end();it++){
        
        gravity_instance_t *gravityIntance=it->second;
        
        scriptManager->dynamicActionFree(scriptManager->vm, (gravity_object_t*)gravityIntance);
        
    }
    
    scriptDynamicActionInstanceMap.clear();
}



void U4DScriptInstanceManager::removeAllScriptInstanceAnimManagers(){
    
    U4DScriptManager *scriptManager=U4DScriptManager::sharedInstance();
    
    std::map<U4DAnimationManager *, gravity_instance_t *>::iterator it;
    
    for(it=scriptAnimManagerInstanceMap.begin();it!=scriptAnimManagerInstanceMap.end();it++){
        
        gravity_instance_t *gravityInstance=it->second;
        
        scriptManager->animationManagerFree(scriptManager->vm, (gravity_object_t*)gravityInstance);
    }
    
    scriptAnimManagerInstanceMap.clear();
}

void U4DScriptInstanceManager::removeAllScriptInstances(){
    
    //removeAllScriptInstanceModels();
    removeAllScriptInstanceAnimations();
    removeAllScriptInstanceDynamicActions();
    removeAllScriptInstanceAnimManagers();
}

}
