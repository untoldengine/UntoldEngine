//
//  U4DGameConfigs.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/5/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DGameConfigs.h"
#include "U4DScriptManager.h"

namespace U4DEngine {

U4DGameConfigs *U4DGameConfigs::instance=0;

U4DGameConfigs* U4DGameConfigs::sharedInstance(){
    
    if(instance==0){
        instance=new U4DGameConfigs();
    }
    
    return instance;
}

U4DGameConfigs::U4DGameConfigs(){
    
}

U4DGameConfigs::~U4DGameConfigs(){
    
}

void U4DGameConfigs::initConfigsMapKeys(const char* uConfigName,...){
    
    va_list args;
    va_start (args, uConfigName);
    
    while (uConfigName) {
        
        std::string name(uConfigName);
        
        configsMap.insert(std::pair<std::string,float>(name, 0.0));
        
        uConfigName=va_arg(args, const char *);
    }

    va_end (args);
    
}

float U4DGameConfigs::getParameterForKey(std::string uName){
    
    std::map<std::string,float>::iterator it=configsMap.find(uName);
    float paramValue=0.0;
    
    if (it != configsMap.end()) {
        paramValue=configsMap.find(uName)->second;
    }
    
    return paramValue;
    
}

void U4DGameConfigs::setParameterForKey(std::string uName, float uValue){

    std::map<std::string,float>::iterator it=configsMap.find(uName);
    
    if (it != configsMap.end()) {
        configsMap.find(uName)->second=uValue;
    }
}

void U4DGameConfigs::loadConfigsMapValues(std::string uFileName){
    
    U4DEngine::U4DScriptManager *scriptManager=U4DEngine::U4DScriptManager::sharedInstance();

    if(scriptManager->init()){
        
        if(scriptManager->loadScript(uFileName)){

            scriptManager->loadGameConfigs();

        }
    }
    
}

void U4DGameConfigs::clearConfigsMap(){
    
    configsMap.clear();
}

}
