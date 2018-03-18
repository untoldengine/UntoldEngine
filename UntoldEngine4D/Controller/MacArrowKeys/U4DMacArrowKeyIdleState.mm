//
//  U4DMacArrowKeyIdleState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/5/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DMacArrowKeyIdleState.h"
namespace U4DEngine {
    
    U4DMacArrowKeyIdleState* U4DMacArrowKeyIdleState::instance=0;
    
    U4DMacArrowKeyIdleState::U4DMacArrowKeyIdleState(){
        
    }
    
    U4DMacArrowKeyIdleState::~U4DMacArrowKeyIdleState(){
        
    }
    
    U4DMacArrowKeyIdleState* U4DMacArrowKeyIdleState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DMacArrowKeyIdleState();
        }
        
        return instance;
        
    }
    
    void U4DMacArrowKeyIdleState::enter(U4DMacArrowKey *uMacArrowKey){
        
    }
    
    void U4DMacArrowKeyIdleState::execute(U4DMacArrowKey *uMacArrowKey, double dt){
        
        
    }
    
    void U4DMacArrowKeyIdleState::exit(U4DMacArrowKey *uMacArrowKey){
        
    }
    
}
