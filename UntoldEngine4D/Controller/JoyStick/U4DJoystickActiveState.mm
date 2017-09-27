//
//  U4DJoystickActiveState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/16/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U4DJoystickActiveState.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {
    
    U4DJoystickActiveState* U4DJoystickActiveState::instance=0;
    
    U4DJoystickActiveState::U4DJoystickActiveState(){
        
    }
    
    U4DJoystickActiveState::~U4DJoystickActiveState(){
        
    }
    
    U4DJoystickActiveState* U4DJoystickActiveState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DJoystickActiveState();
        }
        
        return instance;
        
    }
    
    void U4DJoystickActiveState::enter(U4DJoyStick *uJoyStick){
        
        
    }
    
    void U4DJoystickActiveState::execute(U4DJoyStick *uJoyStick, double dt){
        
        U4DVector3n distance=(uJoyStick->currentPosition-uJoyStick->centerBackgroundPosition);
        
        //magnitude the distance
        float distanceMagnitude=distance.magnitude();
        
        U4DVector3n data=(uJoyStick->currentPosition-uJoyStick->centerBackgroundPosition)/uJoyStick->backgroundImageRadius;
        
        data.normalize();
        
        //get previous data
        U4DVector3n previousData=uJoyStick->getDataPosition();
        
        previousData.normalize();
        //get the direction between previous data and new data
        
        if (previousData.dot(data)<0.0) {
            
            uJoyStick->directionReversal=true;
        }else{
            uJoyStick->directionReversal=false;
        }
        
        uJoyStick->setDataPosition(data);
        
        uJoyStick->dataMagnitude=distanceMagnitude+uJoyStick->dataMagnitude;
        
        if (uJoyStick->pCallback!=NULL) {
            uJoyStick->action();
        }
        
        if (uJoyStick->controllerInterface!=NULL) {
            uJoyStick->controllerInterface->setReceivedAction(true);
        }
        
        uJoyStick->translateTo(uJoyStick->currentPosition);
        
        uJoyStick->joyStickImage.translateTo(uJoyStick->currentPosition);
        
    }
    
    void U4DJoystickActiveState::exit(U4DJoyStick *uJoyStick){
        
    }
    
}
