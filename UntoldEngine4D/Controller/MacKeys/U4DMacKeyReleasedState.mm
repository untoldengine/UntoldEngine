//
//  U4DKeyReleasedState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/3/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DMacKeyReleasedState.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {
    
    U4DMacKeyReleasedState* U4DMacKeyReleasedState::instance=0;
    
    U4DMacKeyReleasedState::U4DMacKeyReleasedState(){
        
    }
    
    U4DMacKeyReleasedState::~U4DMacKeyReleasedState(){
        
    }
    
    U4DMacKeyReleasedState* U4DMacKeyReleasedState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DMacKeyReleasedState();
        }
        
        return instance;
        
    }
    
    void U4DMacKeyReleasedState::enter(U4DMacKey *uMacKey){
        
        
        uMacKey->action();
        
        
        
        if (uMacKey->controllerInterface !=NULL) {
            uMacKey->controllerInterface->setReceivedAction(true);
        }
        
    }
    
    void U4DMacKeyReleasedState::execute(U4DMacKey *uMacKey, double dt){
        
        
    }
    
    void U4DMacKeyReleasedState::exit(U4DMacKey *uMacKey){
        
    }
    
}
