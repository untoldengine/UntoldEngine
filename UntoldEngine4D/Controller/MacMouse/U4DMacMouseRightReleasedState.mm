//
//  U4DMacMouseRightReleaseState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/27/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DMacMouseRightReleasedState.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {
    
    U4DMacMouseRightReleasedState* U4DMacMouseRightReleasedState::instance=0;
    
    U4DMacMouseRightReleasedState::U4DMacMouseRightReleasedState(){
        
    }
    
    U4DMacMouseRightReleasedState::~U4DMacMouseRightReleasedState(){
        
    }
    
    U4DMacMouseRightReleasedState* U4DMacMouseRightReleasedState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DMacMouseRightReleasedState();
        }
        
        return instance;
        
    }
    
    void U4DMacMouseRightReleasedState::enter(U4DMacMouse *uMacMouse){
        
        uMacMouse->dataMagnitude=0.0;
        //uMacMouse->motionAccumulator=U4DVector2n(0.0,0.0);
        
        uMacMouse->action(U4DEngine::mouseRightButtonReleased);
        
        if (uMacMouse->controllerInterface!=NULL) {
            uMacMouse->controllerInterface->setReceivedAction(true);
        }
        
    }
    
    void U4DMacMouseRightReleasedState::execute(U4DMacMouse *uMacMouse, double dt){
        
        
    }
    
    void U4DMacMouseRightReleasedState::exit(U4DMacMouse *uMacMouse){
        
    }
    
}
