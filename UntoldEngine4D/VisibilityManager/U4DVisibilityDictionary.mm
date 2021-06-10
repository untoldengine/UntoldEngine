//
//  U4DVisibilityDictionary.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DVisibilityDictionary.h"
#include <iterator>

namespace U4DEngine {

    U4DVisibilityDictionary* U4DVisibilityDictionary::instance=0;

    U4DVisibilityDictionary::U4DVisibilityDictionary(){
        
    }
        
    U4DVisibilityDictionary::~U4DVisibilityDictionary(){
        
    }
        
    U4DVisibilityDictionary* U4DVisibilityDictionary::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DVisibilityDictionary();
            
        }
        
        return instance;
    }

    void U4DVisibilityDictionary::loadIntoVisibilityDictionary(std::string uName, U4DModel *uModel){
        
        visibilityMap.insert(std::make_pair(uName,uModel));
        
    }

    U4DModel * U4DVisibilityDictionary::getVisibleModel(std::string uName){
        
        std::map<std::string,U4DModel*>::iterator it=visibilityMap.find(uName);
        U4DModel *model=nullptr;
        
        if (it != visibilityMap.end()) {
            model=visibilityMap.find(uName)->second;
        }
        
        return model;
    }

    void U4DVisibilityDictionary::removeFromVisibilityDictionary(std::string uName){
        
        std::map<std::string,U4DModel*>::iterator it=visibilityMap.find(uName);
        
        visibilityMap.erase(it);
    }
}
