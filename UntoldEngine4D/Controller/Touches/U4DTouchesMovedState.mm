//
//  U4DTouchesMovedState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/14/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DTouchesMovedState.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {
    
    U4DTouchesMovedState* U4DTouchesMovedState::instance=0;
    
    U4DTouchesMovedState::U4DTouchesMovedState(){
        
    }
    
    U4DTouchesMovedState::~U4DTouchesMovedState(){
        
    }
    
    U4DTouchesMovedState* U4DTouchesMovedState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DTouchesMovedState();
        }
        
        return instance;
        
    }
    
    void U4DTouchesMovedState::enter(U4DTouches *uTouches){
        
        //code here
        uTouches->action();
        
        if (uTouches->controllerInterface !=NULL) {
            uTouches->controllerInterface->setReceivedAction(true);
        }
        
    }
    
    void U4DTouchesMovedState::execute(U4DTouches *uTouches, double dt){
        
        
    }
    
    void U4DTouchesMovedState::exit(U4DTouches *uTouches){
        
    }
    
}
