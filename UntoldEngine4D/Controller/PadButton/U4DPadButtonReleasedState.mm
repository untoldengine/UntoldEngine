//
//  U4DPadButtonReleasedState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/8/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#include "U4DPadButtonReleasedState.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {
    
    U4DPadButtonReleasedState* U4DPadButtonReleasedState::instance=0;
    
    U4DPadButtonReleasedState::U4DPadButtonReleasedState(){
        
    }
    
    U4DPadButtonReleasedState::~U4DPadButtonReleasedState(){
        
    }
    
    U4DPadButtonReleasedState* U4DPadButtonReleasedState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DPadButtonReleasedState();
        }
        
        return instance;
        
    }
    
    void U4DPadButtonReleasedState::enter(U4DPadButton *uPadButton){
        
        if (uPadButton->pCallback!=NULL) {
            uPadButton->action();
        }
        
        
        if (uPadButton->controllerInterface !=NULL) {
            uPadButton->controllerInterface->setReceivedAction(true);
        }
        
    }
    
    void U4DPadButtonReleasedState::execute(U4DPadButton *uPadButton, double dt){
        
        
    }
    
    void U4DPadButtonReleasedState::exit(U4DPadButton *uPadButton){
        
    }
    
}
