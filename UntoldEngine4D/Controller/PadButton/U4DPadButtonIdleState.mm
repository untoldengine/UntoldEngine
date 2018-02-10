//
//  U4DPadButtonIdleState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/8/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#include "U4DPadButtonIdleState.h"
namespace U4DEngine {
    
    U4DPadButtonIdleState* U4DPadButtonIdleState::instance=0;
    
    U4DPadButtonIdleState::U4DPadButtonIdleState(){
        
    }
    
    U4DPadButtonIdleState::~U4DPadButtonIdleState(){
        
    }
    
    U4DPadButtonIdleState* U4DPadButtonIdleState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DPadButtonIdleState();
        }
        
        return instance;
        
    }
    
    void U4DPadButtonIdleState::enter(U4DPadButton *uPadButton){
        
    }
    
    void U4DPadButtonIdleState::execute(U4DPadButton *uPadButton, double dt){
        
        
    }
    
    void U4DPadButtonIdleState::exit(U4DPadButton *uPadButton){
        
    }
    
}
