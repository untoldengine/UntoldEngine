//
//  U4DPadJoystickActiveState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/10/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DPadJoystickActiveState.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {
    
    U4DPadJoystickActiveState* U4DPadJoystickActiveState::instance=0;
    
    U4DPadJoystickActiveState::U4DPadJoystickActiveState(){
        
    }
    
    U4DPadJoystickActiveState::~U4DPadJoystickActiveState(){
        
    }
    
    U4DPadJoystickActiveState* U4DPadJoystickActiveState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DPadJoystickActiveState();
        }
        
        return instance;
        
    }
    
    void U4DPadJoystickActiveState::enter(U4DPadJoystick *uPadJoystick){
        
        
    }
    
    void U4DPadJoystickActiveState::execute(U4DPadJoystick *uPadJoystick, double dt){
        
        U4DEngine::U4DVector2n padAxis(uPadJoystick->padAxis.x,uPadJoystick->padAxis.y);
        
        if (uPadJoystick->dataPosition.dot(padAxis)<0.0) {
            
            uPadJoystick->directionReversal=true;
            
        }else{
            uPadJoystick->directionReversal=false;
            
        }
        
        uPadJoystick->dataPosition=padAxis;
        
        uPadJoystick->dataMagnitude=padAxis.magnitude();

        uPadJoystick->action();
       
        if (uPadJoystick->controllerInterface!=NULL) {
            uPadJoystick->controllerInterface->setReceivedAction(true);
        }

    }
    
    void U4DPadJoystickActiveState::exit(U4DPadJoystick *uPadJoystick){
        
    }
    
}
