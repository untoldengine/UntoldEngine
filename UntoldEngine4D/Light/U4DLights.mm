//
//  U4DLight.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#include "U4DLights.h"
#include "CommonProtocols.h"

namespace U4DEngine {
    
    U4DLights* U4DLights::instance=0;
    
    U4DLights::U4DLights(){
        
        setEntityType(LIGHT);
      
        //set default position
        translateTo(5.0,5.0,5.0);
        
        //view in direction of
        U4DVector3n origin(0,0,0);
        viewInDirection(origin);
        
    };
    
    U4DLights::~U4DLights(){
        
    };
    
    U4DLights::U4DLights(const U4DLights& value){
        
    }
    
    U4DLights& U4DLights::operator=(const U4DLights& value){
        
        return *this;
        
    };
    
    U4DLights* U4DLights::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DLights();
        }
        
        return instance;
    }

}