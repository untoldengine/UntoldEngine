//
//  U4DButtonIdleState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/15/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DButtonIdleState.h"

namespace U4DEngine {
    
    U4DButtonIdleState* U4DButtonIdleState::instance=0;
    
    U4DButtonIdleState::U4DButtonIdleState(){
        
    }
    
    U4DButtonIdleState::~U4DButtonIdleState(){
        
    }
    
    U4DButtonIdleState* U4DButtonIdleState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DButtonIdleState();
        }
        
        return instance;
        
    }
    
    void U4DButtonIdleState::enter(U4DButton *uButton){
        
    }
    
    void U4DButtonIdleState::execute(U4DButton *uButton, double dt){
        
        
    }
    
    void U4DButtonIdleState::exit(U4DButton *uButton){
        
    }
    
}
