//
//  U4DKeyStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/3/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#include "U4DMacKeyStateManager.h"
#include "U4DMacKey.h"

namespace U4DEngine {
    
    U4DMacKeyStateManager::U4DMacKeyStateManager(U4DMacKey *uMacKey):macKey(uMacKey),previousState(NULL),currentState(NULL){
        
        
    }
    
    U4DMacKeyStateManager::~U4DMacKeyStateManager(){
        
    }
    
    void U4DMacKeyStateManager::changeState(U4DMacKeyStateInterface *uState){
        
        //keep a record of previous state
        previousState=currentState;
        
        //call the exit method of the existing state
        if (currentState!=NULL) {
            currentState->exit(macKey);
        }
        
        //The game pad constantly sends a message to change the state. To prevent it
        //check if the current state is not the same as the new state
        if(currentState!=uState){
            
            //change state to new state
            currentState=uState;
            
            //call the entry method of the new state
            currentState->enter(macKey);
            
        }
        
    }
    
    void U4DMacKeyStateManager::update(double dt){
        
        currentState->execute(macKey, dt);
        
    }
    
    U4DMacKeyStateInterface *U4DMacKeyStateManager::getCurrentState(){
        
        return currentState;
    }
    
}
