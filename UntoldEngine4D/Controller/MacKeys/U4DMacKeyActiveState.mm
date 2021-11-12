//
//  U4DMacKeyActiveState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/12/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DMacKeyActiveState.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {
    
    U4DMacKeyActiveState* U4DMacKeyActiveState::instance=0;
    
    U4DMacKeyActiveState::U4DMacKeyActiveState(){
        
    }
    
    U4DMacKeyActiveState::~U4DMacKeyActiveState(){
        
    }
    
    U4DMacKeyActiveState* U4DMacKeyActiveState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DMacKeyActiveState();
        }
        
        return instance;
        
    }
    
    void U4DMacKeyActiveState::enter(U4DMacKey *uMacKey){
        
        
        
    }
    
    void U4DMacKeyActiveState::execute(U4DMacKey *uMacKey, double dt){
        
        uMacKey->action();

        if (uMacKey->controllerInterface !=NULL) {
            uMacKey->controllerInterface->setReceivedAction(true);
        }
        
    }
    
    void U4DMacKeyActiveState::exit(U4DMacKey *uMacKey){
        
    }
    
}
