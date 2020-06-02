//
//  U4DMacArrowKeyReleasedState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/5/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DMacArrowKeyReleasedState.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {
    
    U4DMacArrowKeyReleasedState* U4DMacArrowKeyReleasedState::instance=0;
    
    U4DMacArrowKeyReleasedState::U4DMacArrowKeyReleasedState(){
        
    }
    
    U4DMacArrowKeyReleasedState::~U4DMacArrowKeyReleasedState(){
        
    }
    
    U4DMacArrowKeyReleasedState* U4DMacArrowKeyReleasedState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DMacArrowKeyReleasedState();
        }
        
        return instance;
        
    }
    
    void U4DMacArrowKeyReleasedState::enter(U4DMacArrowKey *uMacArrowKey){
        
        uMacArrowKey->dataMagnitude=0.0;
        
        
        uMacArrowKey->action();
        
        
        if (uMacArrowKey->controllerInterface!=NULL) {
            uMacArrowKey->controllerInterface->setReceivedAction(true);
        }
        
    }
    
    void U4DMacArrowKeyReleasedState::execute(U4DMacArrowKey *uMacArrowKey, double dt){
        
        
    }
    
    void U4DMacArrowKeyReleasedState::exit(U4DMacArrowKey *uMacArrowKey){
        
    }
    
}
