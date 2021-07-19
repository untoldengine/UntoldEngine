//
//  U4DKineticDictionary.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/9/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DKineticDictionary.h"
#include <iterator>

namespace U4DEngine {

    U4DKineticDictionary* U4DKineticDictionary::instance=0;

    U4DKineticDictionary::U4DKineticDictionary(){
        
    }
        
    U4DKineticDictionary::~U4DKineticDictionary(){
        
    }
        
    U4DKineticDictionary* U4DKineticDictionary::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DKineticDictionary();
            
        }
        
        return instance;
    }

    void U4DKineticDictionary::loadBehaviorDictionary(std::string uName, U4DDynamicAction *uDynamicModel){
        
        kineticBehaviorMap.insert(std::make_pair(uName,uDynamicModel));
        
    }

    U4DDynamicAction * U4DKineticDictionary::getKineticBehavior(std::string uName){
        
        std::map<std::string,U4DDynamicAction*>::iterator it=kineticBehaviorMap.find(uName);
        U4DDynamicAction *kineticBehavior=nullptr;
        
        if (it != kineticBehaviorMap.end()) {
            kineticBehavior=kineticBehaviorMap.find(uName)->second;
        }
        
        return kineticBehavior;
    }

    void U4DKineticDictionary::removeKineticBehavior(std::string uName){
        
        std::map<std::string,U4DDynamicAction*>::iterator it=kineticBehaviorMap.find(uName);
        
        kineticBehaviorMap.erase(it);
    }

    void U4DKineticDictionary::updateKineticBehaviorDictionary(std::string uOriginalName, std::string uNewName){
        
        auto entry=kineticBehaviorMap.find(uOriginalName);
        
        if (entry!=kineticBehaviorMap.end()) {
            
            U4DDynamicAction *dynamicAction=std::move(entry->second);
            kineticBehaviorMap.erase(entry);
            kineticBehaviorMap.insert({uNewName,std::move(dynamicAction)});
            
        }
    }

}

