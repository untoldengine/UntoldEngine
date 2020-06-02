//
//  U4DTouchesStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/14/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DTouchesStateManager.h"
#include "U4DTouches.h"

namespace U4DEngine {
    
    U4DTouchesStateManager::U4DTouchesStateManager(U4DTouches *uTouches):touches(uTouches),previousState(NULL),currentState(NULL){
        
        
    }
    
    U4DTouchesStateManager::~U4DTouchesStateManager(){
        
    }
    
    void U4DTouchesStateManager::changeState(U4DTouchesStateInterface *uState){
        
        //keep a record of previous state
        previousState=currentState;
        
        //call the exit method of the existing state
        if (currentState!=NULL) {
            currentState->exit(touches);
        }
        
        //change state to new state
        currentState=uState;
        
        //call the entry method of the new state
        currentState->enter(touches);
        
    }
    
    void U4DTouchesStateManager::update(double dt){
        
        currentState->execute(touches, dt); 
        
    }
    
    U4DTouchesStateInterface *U4DTouchesStateManager::getCurrentState(){
        
        return currentState;
    }
    
}
