//
//  U4DButtonMovedState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/16/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U4DButtonMovedState.h"

namespace U4DEngine {
    
    U4DButtonMovedState* U4DButtonMovedState::instance=0;
    
    U4DButtonMovedState::U4DButtonMovedState(){
        
    }
    
    U4DButtonMovedState::~U4DButtonMovedState(){
        
    }
    
    U4DButtonMovedState* U4DButtonMovedState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DButtonMovedState();
        }
        
        return instance;
        
    }
    
    void U4DButtonMovedState::enter(U4DButton *uButton){
        
    }
    
    void U4DButtonMovedState::execute(U4DButton *uButton, double dt){
        
        
    }
    
    void U4DButtonMovedState::exit(U4DButton *uButton){
        
    }
    
}
