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
    
    
U4DJoyStick::U4DJoyStick(std::string uName, float xPosition,float yPosition,const char* uBackGroundImage,float uBackgroundWidth,float uBackgroundHeight,const char* uJoyStickImage,float uJoyStickWidth,float uJoyStickHeight,U4DCallbackInterface *uAction):joyStickState(rTouchesNull){
    
    
    setName(uName);
    
    joyStickWidth=uJoyStickWidth;
    joyStickHeight=uJoyStickHeight;
    
    //copy the width and height of the image to the button
    backgroundWidth=uBackgroundWidth;
    backgroundHeight=uBackgroundHeight;
    
    
    backgroundImage.setImage(uBackGroundImage,uBackgroundWidth,uBackgroundHeight);
    
    
    U4DVector3n translation(xPosition,yPosition,0.0);
    translateTo(translation);     //move the joyStick
    
    
    backgroundImage.translateTo(translation);  //move the image
    
    //add the joy stick
    joyStickImage.setImage(uJoyStickImage,uJoyStickWidth,uJoyStickHeight);
    joyStickImage.translateTo(translation);
    
    
    //set the callback
    pCallback=uAction;
    
    //get the original center position of the joystick
    originalPosition=getLocalPosition();
    
    
    //get the coordinates of the box
    centerBackgroundPosition=backgroundImage.getLocalPosition();
    centerImagePosition=getLocalPosition();
    
    U4DDirector *director=U4DDirector::sharedInstance();
    
    backgroundImageRadius=getJoyStickBackgroundWidth()/director->getDisplayWidth();;
    joyStickImageRadius=getJoyStickWidth()/director->getDisplayWidth();
    
    
}
    
U4DJoyStick::~U4DJoyStick(){

}
    
void U4DJoyStick::setJoyStickBackgroundWidth(float uJoyStickBackgroundWidth){
    
    backgroundWidth=uJoyStickBackgroundWidth;

}

void U4DJoyStick::setJoyStickBackgroundHeight(float uJoyStickBackgroundHeight){
    
    backgroundHeight=uJoyStickBackgroundHeight;

}
    
void U4DJoyStick::setJoyStickWidth(float uJoyStickWidth){
    
    joyStickWidth=uJoyStickWidth;

}

void U4DJoyStick::setJoyStickHeight(float uJoyStickHeight){
    
    joyStickHeight=uJoyStickHeight;

}

float U4DJoyStick::getJoyStickWidth(){
    
    return joyStickWidth;

}

float U4DJoyStick::getJoyStickHeight(){
    
    return joyStickHeight;

}

float U4DJoyStick::getJoyStickBackgroundWidth(){
    
    return backgroundWidth;

}

float U4DJoyStick::getJoyStickBackgroundHeight(){
    
    return backgroundHeight;

}

void U4DJoyStick::setDataMagnitude(float uValue){
    
    dataMagnitude=uValue;

}

float U4DJoyStick::getDataMagnitude(){
    
    return dataMagnitude;

}
    
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
