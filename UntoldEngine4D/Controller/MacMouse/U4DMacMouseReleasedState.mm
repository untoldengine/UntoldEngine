//
//  U4DMacMouseReleasedState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/8/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DMacMouseReleasedState.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {
    
    U4DMacMouseReleasedState* U4DMacMouseReleasedState::instance=0;
    
    U4DMacMouseReleasedState::U4DMacMouseReleasedState(){
        
    }
    
    U4DMacMouseReleasedState::~U4DMacMouseReleasedState(){
        
    }
    
    U4DMacMouseReleasedState* U4DMacMouseReleasedState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DMacMouseReleasedState();
        }
        
        return instance;
        
    }
    
    void U4DMacMouseReleasedState::enter(U4DMacMouse *uMacMouse){
        
        uMacMouse->dataMagnitude=0.0;
        
        if (uMacMouse->pCallback!=NULL) {
            uMacMouse->action();
        }
        
        if (uMacMouse->controllerInterface!=NULL) {
            uMacMouse->controllerInterface->setReceivedAction(true);
        }
        
    }
    
    void U4DMacMouseReleasedState::execute(U4DMacMouse *uMacMouse, double dt){
        
        
    }
    
    void U4DMacMouseReleasedState::exit(U4DMacMouse *uMacMouse){
        
    }
    
}
