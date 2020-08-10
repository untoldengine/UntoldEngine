//
//  U4DJoystickActiveState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/16/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
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
        
        U4DVector2n joystickCenterBackgroundPosition(uJoyStick->centerBackgroundPosition.x,uJoyStick->centerBackgroundPosition.y);
        
        U4DVector2n distance=(uJoyStick->currentPosition-joystickCenterBackgroundPosition);
        
        //magnitude the distance
        float distanceMagnitude=distance.magnitude();
        
        U4DVector2n data=(uJoyStick->currentPosition-joystickCenterBackgroundPosition)/uJoyStick->backgroundImageRadius;
        
        data.normalize();
        
        //get previous data
        U4DVector2n previousData=uJoyStick->getDataPosition();
        
        previousData.normalize();
        //get the direction between previous data and new data
        
        if (previousData.dot(data)<0.0) {
            
            uJoyStick->directionReversal=true;
        }else{
            uJoyStick->directionReversal=false;
        }
        
        uJoyStick->setDataPosition(data);
        
        uJoyStick->dataMagnitude=distanceMagnitude+uJoyStick->dataMagnitude;
        
        uJoyStick->action();
        
        if (uJoyStick->controllerInterface!=NULL) {
            uJoyStick->controllerInterface->setReceivedAction(true);
        }
        
        uJoyStick->translateTo(uJoyStick->currentPosition);
        
        uJoyStick->joyStickImage.translateTo(uJoyStick->currentPosition);
        
    }
    
    void U4DJoystickActiveState::exit(U4DJoyStick *uJoyStick){
        
    }
    
}
