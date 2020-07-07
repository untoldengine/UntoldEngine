//
//  U4DJoyStick.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/17/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DJoyStick.h"
#include "U4DVector2n.h"
#include "U4DDirector.h"
#include "U4DControllerInterface.h"
#include "U4DJoystickStateManager.h"
#include "U4DJoystickIdleState.h"
#include "U4DJoystickActiveState.h"
#include "U4DJoystickReleasedState.h"

namespace U4DEngine {
    
    
U4DJoyStick::U4DJoyStick(std::string uName, float xPosition,float yPosition,const char* uBackGroundImage,float uBackgroundWidth,float uBackgroundHeight,const char* uJoyStickImage,float uJoyStickWidth,float uJoyStickHeight):isActive(false),controllerInterface(NULL),pCallback(NULL),directionReversal(false),dataPosition(0.0,0.0),dataMagnitude(0.0){
    
    stateManager=new U4DJoystickStateManager(this);
    
    setName(uName);
    
    setEntityType(CONTROLLERINPUT);
    
    joyStickWidth=uJoyStickWidth;
    joyStickHeight=uJoyStickHeight;
    
    //copy the width and height of the image to the button
    backgroundWidth=uBackgroundWidth;
    backgroundHeight=uBackgroundHeight;
    
    
    backgroundImage.setImage(uBackGroundImage,uBackgroundWidth,uBackgroundHeight);
    
    
    U4DVector2n translation(xPosition,yPosition);
    translateTo(translation);     //move the joyStick
    
    
    backgroundImage.translateTo(translation);  //move the image
    
    //add the joy stick
    joyStickImage.setImage(uJoyStickImage,uJoyStickWidth,uJoyStickHeight);
    joyStickImage.translateTo(translation);

    
    //get the original center position of the joystick
    originalPosition.x=getLocalPosition().x;
    originalPosition.y=getLocalPosition().y;
    
    
    //get the coordinates of the box
    centerBackgroundPosition.x=backgroundImage.getLocalPosition().x;
    centerBackgroundPosition.y=backgroundImage.getLocalPosition().y;
    
    centerImagePosition.x=getLocalPosition().x;
    centerImagePosition.y=getLocalPosition().y;
    
    U4DDirector *director=U4DDirector::sharedInstance();
    
    backgroundImageRadius=getJoyStickBackgroundWidth()/director->getDisplayWidth();;
    joyStickImageRadius=getJoyStickWidth()/director->getDisplayWidth();
    
    //set initial state
    stateManager->changeState(U4DJoystickIdleState::sharedInstance());
    
}
    
U4DJoyStick::~U4DJoyStick(){

    delete stateManager;
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
    
void U4DJoyStick::render(id <MTLRenderCommandEncoder> uRenderEncoder){
    
    backgroundImage.render(uRenderEncoder);
    joyStickImage.render(uRenderEncoder);
}

void U4DJoyStick::update(double dt){
    
    stateManager->update(dt);

}

void U4DJoyStick::action(){
    
    pCallback->action();
}

bool U4DJoyStick::changeState(INPUTELEMENTACTION uInputAction, U4DVector2n uPosition){
    
    bool withinBoundary=false;
    
    U4DVector2n pos(uPosition.x,uPosition.y);
    
    U4DVector2n distance=(pos-centerBackgroundPosition);
    
    float distanceMagnitude=distance.magnitude();
    
    float distancePlusJoyStick=distanceMagnitude+joyStickImageRadius;
    
    if (distancePlusJoyStick<=(backgroundImageRadius+backgroundImageRadius*2.5)){
        
        currentPosition=uPosition;
        withinBoundary=true;
        
        if (uInputAction==U4DEngine::ioTouchesBegan || uInputAction==U4DEngine::ioTouchesMoved) {
            
            stateManager->changeState(U4DJoystickActiveState::sharedInstance());
            
        }else if(uInputAction==U4DEngine::ioTouchesEnded && (stateManager->getCurrentState()==U4DJoystickActiveState::sharedInstance())){
            
            stateManager->changeState(U4DJoystickReleasedState::sharedInstance());
            
        }
        
    }
    
    return withinBoundary;
}

void U4DJoyStick::setDataPosition(U4DVector2n uData){
    
    dataPosition=uData;
}

U4DVector2n U4DJoyStick::getDataPosition(){
    
    return dataPosition;
}
    
bool U4DJoyStick::getIsActive(){
    
    return (stateManager->getCurrentState()==U4DJoystickActiveState::sharedInstance());;
}

void U4DJoyStick::setCallbackAction(U4DCallbackInterface *uAction){
    
    //set the callback
    pCallback=uAction;
    
}
    
void U4DJoyStick::setControllerInterface(U4DControllerInterface* uControllerInterface){
    
    controllerInterface=uControllerInterface;
    
}
    
bool U4DJoyStick::getDirectionReversal(){
    
    return directionReversal;
    
}
    
}
