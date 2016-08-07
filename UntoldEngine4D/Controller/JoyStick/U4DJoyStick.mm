//
//  U4DJoyStick.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/17/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DJoyStick.h"
#include "U4DVector2n.h"
#include "U4DDirector.h"

namespace U4DEngine {
    
void U4DJoyStick::draw(){
    
    backgroundImage.draw();
    joyStickImage.draw();
}

void U4DJoyStick::update(float dt){
    
    if ( joyStickState==rTouchesBegan ||  joyStickState==rTouchesMoved) {
        
        U4DVector3n distance=(currentPosition-centerBackgroundPosition);
        
        //magnitude the distance
        float distanceMagnitude=distance.magnitude();
        
        float distancePlusJoyStick=distanceMagnitude+joyStickImageRadius;
        
        if (distancePlusJoyStick<=backgroundImageRadius) {
            
            U4DVector3n data=(currentPosition-centerBackgroundPosition)/backgroundImageRadius;
            data.normalize();
            setDataPosition(data);
            
            translateTo(currentPosition);
            joyStickImage.translateTo(currentPosition);
            
            dataMagnitude=distanceMagnitude+dataMagnitude;
            
            action();
            
        }else{
            changeState(rTouchesEnded);
        }
        
        
    }if ( joyStickState==rTouchesEnded){
        
        translateTo(originalPosition);
        joyStickImage.translateTo(originalPosition);
        
        dataPosition=originalPosition;
        dataMagnitude=0.0;
    }

}

void U4DJoyStick::action(){
    
    pCallback->action();
}


void U4DJoyStick::changeState(TOUCHSTATE uTouchState,U4DVector3n uNewPosition){
    
    joyStickState=uTouchState;
    currentPosition=uNewPosition;
    
}

void U4DJoyStick::changeState(TOUCHSTATE uTouchState){
    
    joyStickState=uTouchState;
    
    if ( joyStickState==rTouchesEnded){
        
               
    }
    
}

TOUCHSTATE U4DJoyStick::getState(){
    
    return joyStickState;
}

void U4DJoyStick::setDataPosition(U4DVector3n uData){
    
    dataPosition=uData;
}

U4DVector3n U4DJoyStick::getDataPosition(){
    
    return dataPosition;
}
    
}
