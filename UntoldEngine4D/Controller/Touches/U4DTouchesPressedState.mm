//
//  U4DTouchesPressedState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/14/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DTouchesPressedState.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {
    
    U4DTouchesPressedState* U4DTouchesPressedState::instance=0;
    
    U4DTouchesPressedState::U4DTouchesPressedState(){
        
    }
    
    U4DTouchesPressedState::~U4DTouchesPressedState(){
        
    }
    
    U4DTouchesPressedState* U4DTouchesPressedState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DTouchesPressedState();
        }
        
        return instance;
        
    }
    
    void U4DTouchesPressedState::enter(U4DTouches *uTouches){
        
        //code here
        
        uTouches->action();
        
        if (uTouches->controllerInterface !=NULL) {
            uTouches->controllerInterface->setReceivedAction(true);
        }
        
    }
    
    void U4DTouchesPressedState::execute(U4DTouches *uTouches, double dt){
        
        
    }
    
    void U4DTouchesPressedState::exit(U4DTouches *uTouches){
        
    }
    
}
