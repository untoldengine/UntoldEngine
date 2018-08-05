//
//  U4DMacMouseStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/8/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DMacMouseStateManager.h"
#include "U4DMacMouse.h"

namespace U4DEngine {
    
    U4DMacMouseStateManager::U4DMacMouseStateManager(U4DMacMouse *uMacMouse):macMouse(uMacMouse),previousState(NULL),currentState(NULL){
        
        
    }
    
    U4DMacMouseStateManager::~U4DMacMouseStateManager(){
        
    }
    
    void U4DMacMouseStateManager::changeState(U4DMacMouseStateInterface *uState){
        
        //keep a record of previous state
        previousState=currentState;
        
        //call the exit method of the existing state
        if (currentState!=NULL) {
            currentState->exit(macMouse);
        }
        
        //change state to new state
        currentState=uState;
        
        //call the entry method of the new state
        currentState->enter(macMouse);
        
    }
    
    void U4DMacMouseStateManager::update(double dt){
        
        currentState->execute(macMouse, dt);
        
    }
    
    U4DMacMouseStateInterface *U4DMacMouseStateManager::getCurrentState(){
        
        return currentState;
    }
    
}
