//
//  U4DMacMouseIdleState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/8/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DMacMouseIdleState.h"
namespace U4DEngine {
    
    U4DMacMouseIdleState* U4DMacMouseIdleState::instance=0;
    
    U4DMacMouseIdleState::U4DMacMouseIdleState(){
        
    }
    
    U4DMacMouseIdleState::~U4DMacMouseIdleState(){
        
    }
    
    U4DMacMouseIdleState* U4DMacMouseIdleState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DMacMouseIdleState();
        }
        
        return instance;
        
    }
    
    void U4DMacMouseIdleState::enter(U4DMacMouse *uMacMouse){
        
    }
    
    void U4DMacMouseIdleState::execute(U4DMacMouse *uMacMouse, double dt){
        
        
    }
    
    void U4DMacMouseIdleState::exit(U4DMacMouse *uMacMouse){
        
    }
    
}
