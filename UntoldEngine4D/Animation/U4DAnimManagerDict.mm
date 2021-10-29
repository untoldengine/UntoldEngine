//
//  U4DAnimManagerDict.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/20/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DAnimManagerDict.h"

namespace U4DEngine {

    U4DAnimManagerDict* U4DAnimManagerDict::instance=0;

    U4DAnimManagerDict::U4DAnimManagerDict(){
        
    }
        
    U4DAnimManagerDict::~U4DAnimManagerDict(){
        
    }
        
    U4DAnimManagerDict* U4DAnimManagerDict::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DAnimManagerDict();
            
        }
        
        return instance;
    }

void U4DAnimManagerDict::loadAnimManagerDictionary(std::string uName, U4DAnimationManager *uAnimationManager){
    
    auto entry=animationManagerMap.find(uName);
    
    //Make sure we are not adding more than one dynamic action to the model
    if (entry!=animationManagerMap.end()) {
        
        U4DAnimationManager *previousAnimationManager=std::move(entry->second);
        
        delete previousAnimationManager;
        
        animationManagerMap.insert({uName,std::move(uAnimationManager)});
        
    }else{

        animationManagerMap.insert(std::make_pair(uName,uAnimationManager));
        
        
    }
    
}

U4DAnimationManager *U4DAnimManagerDict::getAnimManager(std::string uName){
    
    std::map<std::string,U4DAnimationManager*>::iterator it=animationManagerMap.find(uName);
    U4DAnimationManager *animationManager=nullptr;
    
    if (it != animationManagerMap.end()) {
        animationManager=animationManagerMap.find(uName)->second;
    }
    
    return animationManager;
    
} 

void U4DAnimManagerDict::removeAnimManager(std::string uName){
    
    std::map<std::string,U4DAnimationManager*>::iterator it=animationManagerMap.find(uName);
    
    animationManagerMap.erase(it);
}

void U4DAnimManagerDict::updateAnimManagerDictionary(std::string uOriginalName, std::string uNewName){
    
    auto entry=animationManagerMap.find(uOriginalName);
    
    if (entry!=animationManagerMap.end()) {
        
        U4DAnimationManager *animationManager=std::move(entry->second);
        animationManagerMap.erase(entry);
        animationManagerMap.insert({uNewName,std::move(animationManager)});
        
    }
    
}


}
