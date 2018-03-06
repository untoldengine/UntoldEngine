//
//  U4DKeyIdleState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/3/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#include "U4DMacKeyIdleState.h"

namespace U4DEngine {
    
    U4DMacKeyIdleState* U4DMacKeyIdleState::instance=0;
    
    U4DMacKeyIdleState::U4DMacKeyIdleState(){
        
    }
    
    U4DMacKeyIdleState::~U4DMacKeyIdleState(){
        
    }
    
    U4DMacKeyIdleState* U4DMacKeyIdleState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DMacKeyIdleState();
        }
        
        return instance;
        
    }
    
    void U4DMacKeyIdleState::enter(U4DMacKey *uMacKey){
        
    }
    
    void U4DMacKeyIdleState::execute(U4DMacKey *uMacKey, double dt){
        
        
    }
    
    void U4DMacKeyIdleState::exit(U4DMacKey *uMacKey){
        
    }
    
}
