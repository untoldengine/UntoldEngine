//
//  U4DTouchesIdleState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/14/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DTouchesIdleState.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {
    
    U4DTouchesIdleState* U4DTouchesIdleState::instance=0;
    
    U4DTouchesIdleState::U4DTouchesIdleState(){
        
    }
    
    U4DTouchesIdleState::~U4DTouchesIdleState(){
        
    }
    
    U4DTouchesIdleState* U4DTouchesIdleState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DTouchesIdleState();
        }
        
        return instance;
        
    }
    
    void U4DTouchesIdleState::enter(U4DTouches *uTouches){
        
        //code here
        
        
        uTouches->action();
        
        if (uTouches->controllerInterface !=NULL) {
            uTouches->controllerInterface->setReceivedAction(true);
        }
        
    }
    
    void U4DTouchesIdleState::execute(U4DTouches *uTouches, double dt){
        
        
    }
    
    void U4DTouchesIdleState::exit(U4DTouches *uTouches){
        
    }
    
}
