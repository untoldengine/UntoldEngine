//
//  U4DMacMouseExitedState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/18/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "U4DMacMouseExitedState.h"
namespace U4DEngine {
    
    U4DMacMouseExitedState* U4DMacMouseExitedState::instance=0;
    
    U4DMacMouseExitedState::U4DMacMouseExitedState(){
        
    }
    
    U4DMacMouseExitedState::~U4DMacMouseExitedState(){
        
    }
    
    U4DMacMouseExitedState* U4DMacMouseExitedState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DMacMouseExitedState();
        }
        
        return instance;
        
    }
    
    void U4DMacMouseExitedState::enter(U4DMacMouse *uMacMouse){
        
    }
    
    void U4DMacMouseExitedState::execute(U4DMacMouse *uMacMouse, double dt){
        
        
    }
    
    void U4DMacMouseExitedState::exit(U4DMacMouse *uMacMouse){
        
    }
    
}
