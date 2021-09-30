//
//  U4DScriptInstanceManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DScriptInstanceManager.h"
#include "U4DScriptBindModel.h"
#include "U4DScriptBindAnimation.h"
#include "U4DScriptBindAnimManager.h"
#include "U4DScriptBindDynamicAction.h"
#include "U4DScriptBindManager.h"
#include "U4DScriptBindBehavior.h"

namespace U4DEngine{

U4DScriptInstanceManager* U4DScriptInstanceManager::instance=0;

U4DScriptInstanceManager* U4DScriptInstanceManager::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DScriptInstanceManager();
    }

    return instance;
}

U4DScriptInstanceManager::U4DScriptInstanceManager():modelInstanceIndex(1),scriptBehaviorInstanceIndex(1){
     
        
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

void U4DScriptInstanceManager::loadScriptBehaviorInstance(U4DScriptBehavior *uScriptBehavior, gravity_instance_t *uGravityInstance){
    
    uScriptBehavior->setScriptID(scriptBehaviorInstanceIndex);
    
    scriptBehaviorInstanceMap.insert(std::make_pair(scriptBehaviorInstanceIndex,uGravityInstance));
    
    scriptBehaviorInstanceIndex++;
    
}

gravity_instance_t *U4DScriptInstanceManager::getScriptBehaviorInstance(int uScriptID){
    
    std::map<int,gravity_instance_t*>::iterator it=scriptBehaviorInstanceMap.find(uScriptID);
    gravity_instance_t* gravityScriptBehaviorInstance=nullptr;
    
    if (it != scriptBehaviorInstanceMap.end()) {
        gravityScriptBehaviorInstance=scriptBehaviorInstanceMap.find(uScriptID)->second;
    }
    
    return gravityScriptBehaviorInstance;
    
}

bool U4DScriptInstanceManager::modelScriptInstanceExist(int uScriptID){
    
    std::map<int,gravity_instance_t*>::iterator it=scriptModelInstanceMap.find(uScriptID);
    
    bool scriptPresent=false;
    
    if (it != scriptModelInstanceMap.end()) {
        scriptPresent=true;
    }
    
    return scriptPresent;
    
}

void U4DScriptInstanceManager::removeModelScriptInstance(int uScriptID){
    
    std::map<int,gravity_instance_t*>::iterator it=scriptModelInstanceMap.find(uScriptID);
    
    scriptModelInstanceMap.erase(it);
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
    
    U4DScriptBindAnimation *scriptBindAnimation=U4DScriptBindAnimation::sharedInstance();
    U4DScriptBindManager *scriptBindManager=U4DScriptBindManager::sharedInstance();
    
    std::map<U4DAnimation *, gravity_instance_t *>::iterator it;
    
    for(it=scriptAnimationInstanceMap.begin();it!=scriptAnimationInstanceMap.end();it++){
        
        //U4DAnimation *animation=it->first;
        gravity_instance_t *gravityInstance=it->second;
        
        scriptBindAnimation->animationFree(scriptBindManager->vm, (gravity_object_t*)gravityInstance);
    }
    
    scriptAnimationInstanceMap.clear();
    
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

void U4DScriptInstanceManager::removeAllScriptInstanceModels(){
    
    U4DScriptBindManager *scriptBindManager=U4DScriptBindManager::sharedInstance();
    U4DScriptBindModel *scriptBindModel=U4DScriptBindModel::sharedInstance();
    
    std::map<int,gravity_instance_t*>::iterator it;
    
    for(it=scriptModelInstanceMap.begin();it!=scriptModelInstanceMap.end();it++){
        
        gravity_instance_t *gravityIntance=it->second;
        
        scriptBindModel->modelFree(scriptBindManager->vm, (gravity_object_t*)gravityIntance);
        
    }
    
    scriptModelInstanceMap.clear();
}

void U4DScriptInstanceManager::removeAllScriptInstanceDynamicActions(){
    
    U4DScriptBindManager *scriptBindManager=U4DScriptBindManager::sharedInstance();
    U4DScriptBindDynamicAction *scriptBindDynamicAction=U4DScriptBindDynamicAction::sharedInstance();
    
    std::map<U4DDynamicAction*,gravity_instance_t*>::iterator it;
    
    for(it=scriptDynamicActionInstanceMap.begin();it!=scriptDynamicActionInstanceMap.end();it++){
        
        gravity_instance_t *gravityIntance=it->second;
        
        scriptBindDynamicAction->dynamicActionFree(scriptBindManager->vm, (gravity_object_t*)gravityIntance);
        
    }
    
    scriptDynamicActionInstanceMap.clear();
}

void U4DScriptInstanceManager::removeAllScriptInstanceAnimManagers(){
    
    U4DScriptBindAnimManager *scriptBindAnimManager=U4DScriptBindAnimManager::sharedInstance();
    U4DScriptBindManager *scriptBindManager=U4DScriptBindManager::sharedInstance();
    
    std::map<U4DAnimationManager *, gravity_instance_t *>::iterator it;
    
    for(it=scriptAnimManagerInstanceMap.begin();it!=scriptAnimManagerInstanceMap.end();it++){
        
        gravity_instance_t *gravityInstance=it->second;
        
        scriptBindAnimManager->animationManagerFree(scriptBindManager->vm, (gravity_object_t*)gravityInstance);
    }
    
    scriptAnimManagerInstanceMap.clear();
}

void U4DScriptInstanceManager::removeAllScriptBehaviorInstances(){
    
    U4DScriptBindManager *scriptBindManager=U4DScriptBindManager::sharedInstance();
    U4DScriptBindBehavior *scriptBindBehavior=U4DScriptBindBehavior::sharedInstance();
    
    std::map<int,gravity_instance_t*>::iterator it;
    
    for(it=scriptBehaviorInstanceMap.begin();it!=scriptBehaviorInstanceMap.end();it++){
        
        gravity_instance_t *gravityIntance=it->second;
        
        scriptBindBehavior->scriptBehaviorFree(scriptBindManager->vm, (gravity_object_t*)gravityIntance);
        
    }
    
    scriptBehaviorInstanceMap.clear();
    
}

void U4DScriptInstanceManager::removeAllScriptInstances(){
    
//    removeAllScriptInstanceModels();
//    removeAllScriptInstanceAnimations();
//    removeAllScriptInstanceDynamicActions();
//    removeAllScriptInstanceAnimManagers();
    removeAllScriptBehaviorInstances();
}

}
