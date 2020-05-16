//
//  U4DTouchesReleasedState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/14/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DTouchesReleasedState.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {
    
    U4DTouchesReleasedState* U4DTouchesReleasedState::instance=0;
    
    U4DTouchesReleasedState::U4DTouchesReleasedState(){
        
    }
    
    U4DTouchesReleasedState::~U4DTouchesReleasedState(){
        
    }
    
    U4DTouchesReleasedState* U4DTouchesReleasedState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DTouchesReleasedState();
        }
        
        return instance;
        
    }
    
    void U4DTouchesReleasedState::enter(U4DTouches *uTouches){
        
        //code here
        
        uTouches->action();
        
        if (uTouches->controllerInterface !=NULL) {
            uTouches->controllerInterface->setReceivedAction(true);
        }
        
    }
    
    void U4DTouchesReleasedState::execute(U4DTouches *uTouches, double dt){
        
        
    }
    
    void U4DTouchesReleasedState::exit(U4DTouches *uTouches){
        
    }
    
}
