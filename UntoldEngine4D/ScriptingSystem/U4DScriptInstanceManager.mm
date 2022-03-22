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

void U4DScriptInstanceManager::loadAISeekScriptInstance(U4DSeek *uAISeek, gravity_instance_t *uGravityInstance){
    scriptAISeekInstanceMap.insert(std::make_pair(uAISeek,uGravityInstance));
}

gravity_instance_t *U4DScriptInstanceManager::getAISeekScriptInstance(U4DSeek *uAISeek){
    
    std::map<U4DSeek*,gravity_instance_t*>::iterator it=scriptAISeekInstanceMap.find(uAISeek);
    
    gravity_instance_t* gravityAISeekInstance=nullptr;
    
    if (it != scriptAISeekInstanceMap.end()) {
        gravityAISeekInstance=scriptAISeekInstanceMap.find(uAISeek)->second;
    }
    
    return gravityAISeekInstance;
}

void U4DScriptInstanceManager::loadAIArriveScriptInstance(U4DArrive *uAIArrive, gravity_instance_t *uGravityInstance){
    scriptAIArriveInstanceMap.insert(std::make_pair(uAIArrive,uGravityInstance));
}

gravity_instance_t *U4DScriptInstanceManager::getAIArriveScriptInstance(U4DArrive *uAIArrive){
    
        std::map<U4DArrive*,gravity_instance_t*>::iterator it=scriptAIArriveInstanceMap.find(uAIArrive);
        
        gravity_instance_t* gravityAIArriveInstance=nullptr;
        
        if (it != scriptAIArriveInstanceMap.end()) {
            gravityAIArriveInstance=scriptAIArriveInstanceMap.find(uAIArrive)->second;
        }
        
        return gravityAIArriveInstance;
}

void U4DScriptInstanceManager::loadTeamScriptInstance(U4DTeam *uTeam, gravity_instance_t *uGravityInstance){
    
    scriptTeamInstanceMap.insert(std::make_pair(uTeam,uGravityInstance));
    
}

gravity_instance_t *U4DScriptInstanceManager::getTeamScriptInstance(U4DTeam *uTeam){
    
    std::map<U4DTeam*,gravity_instance_t*>::iterator it=scriptTeamInstanceMap.find(uTeam);
    
    gravity_instance_t* gravityTeamInstance=nullptr;
    
    if (it != scriptTeamInstanceMap.end()) {
        gravityTeamInstance=scriptTeamInstanceMap.find(uTeam)->second;
    }
    
    return gravityTeamInstance;
    
}

U4DTeam *U4DScriptInstanceManager::getControllingTeam(){
    
    //traverse the map and get the team with setAI as false
    std::map<U4DTeam*,gravity_instance_t*>::iterator it;
    
    for(it=scriptTeamInstanceMap.begin(); it!=scriptTeamInstanceMap.end();it++ ){
    
        U4DTeam *team=it->first;
        
        if(team->aiTeam==false){
            
            return team;
        }
        
    }
    
    return nullptr;
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

void U4DScriptInstanceManager::removeAllScriptInstanceAISeek(){
    
    U4DScriptManager *scriptManager=U4DScriptManager::sharedInstance();
    
    std::map<U4DSeek*,gravity_instance_t*>::iterator it;
    
    for(it=scriptAISeekInstanceMap.begin();it!=scriptAISeekInstanceMap.end();it++){
        
        gravity_instance_t *gravityIntance=it->second;
        
        scriptManager->aiSeekFree(scriptManager->vm, (gravity_object_t*)gravityIntance);
        
    }
    
    scriptAISeekInstanceMap.clear();
    
}

void U4DScriptInstanceManager::removeAllScriptInstanceAIArrive(){
    
    U4DScriptManager *scriptManager=U4DScriptManager::sharedInstance();
    
    std::map<U4DArrive*,gravity_instance_t*>::iterator it;
    
    for(it=scriptAIArriveInstanceMap.begin();it!=scriptAIArriveInstanceMap.end();it++){
        
        gravity_instance_t *gravityIntance=it->second;
        
        scriptManager->aiArriveFree(scriptManager->vm, (gravity_object_t*)gravityIntance);
        
    }
    
    scriptAIArriveInstanceMap.clear();
}

void U4DScriptInstanceManager::removeAllScriptInstanceTeam(){
    
    U4DScriptManager *scriptManager=U4DScriptManager::sharedInstance();
    
    std::map<U4DTeam*,gravity_instance_t*>::iterator it;
    
    for(it=scriptTeamInstanceMap.begin();it!=scriptTeamInstanceMap.end();it++){
        
        gravity_instance_t *gravityIntance=it->second;
        
        scriptManager->teamFree(scriptManager->vm, (gravity_object_t*)gravityIntance);
        
    }
    
    scriptTeamInstanceMap.clear();
}

void U4DScriptInstanceManager::removeAllScriptInstances(){
    
    //removeAllScriptInstanceModels();
    removeAllScriptInstanceAnimations();
    removeAllScriptInstanceDynamicActions();
    removeAllScriptInstanceAnimManagers();
    removeAllScriptInstanceAISeek();
    removeAllScriptInstanceAIArrive();
    removeAllScriptInstanceTeam();
}

}
