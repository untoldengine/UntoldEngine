//
//  U4DLogger.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/7/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "U4DLogger.h"
#include <iostream>

namespace U4DEngine {

    U4DLogger::U4DLogger(){
    }
    
    U4DLogger::~U4DLogger(){
        
    }
    
    U4DLogger::U4DLogger(const U4DLogger& value){
        
    }
    
    U4DLogger& U4DLogger::operator=(const U4DLogger& value){
        
        return *this;
        
    };
    
    
    U4DLogger* U4DLogger::instance=0;
    
    U4DLogger* U4DLogger::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DLogger();
        }
        
        return instance;
    }
    
    void U4DLogger::log(const char* uLog){
        
        std::cout<<uLog<<std::endl;
        
    }

    
}