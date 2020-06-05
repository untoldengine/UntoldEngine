//
//  MobileLayer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/3/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "MobileLayer.h"
#include "U4DLayerManager.h"
#include "U4DCallback.h"
#include "UserCommonProtocols.h"

MobileLayer::MobileLayer(std::string uLayerName):U4DLayer(uLayerName),pPlayer(nullptr){
    
}

MobileLayer::~MobileLayer(){
    
}

void MobileLayer::init(){
    
    //Create UI Elements
    
    //create the Joystick
    joystick=new U4DEngine::U4DJoyStick("joystick",-0.7,-0.6,"joyStickBackground.png",130.0,130.0,"joystickDriver.png",80.0,80.0);
    
    //create the buttons
    buttonA=new U4DEngine::U4DButton("buttonA",0.3,-0.6,103.0,103.0,"ButtonA.png","ButtonAPressed.png");
    buttonB=new U4DEngine::U4DButton("buttonB",0.7,-0.6,103.0,103.0,"ButtonB.png","ButtonBPressed.png");
    
    //create the callbacks
    //Joystick callback
    U4DEngine::U4DCallback<MobileLayer>* joystickCallback=new U4DEngine::U4DCallback<MobileLayer>;
    joystickCallback->scheduleClassWithMethod(this, &MobileLayer::actionOnJoystick);
    joystick->setCallbackAction(joystickCallback);
    
    //ButtonA callback
    U4DEngine::U4DCallback<MobileLayer>* buttonACallback=new U4DEngine::U4DCallback<MobileLayer>;
    buttonACallback->scheduleClassWithMethod(this, &MobileLayer::actionOnButtonA);
    buttonA->setCallbackAction(buttonACallback);
    
    //ButtonB callback
    U4DEngine::U4DCallback<MobileLayer>* buttonBCallback=new U4DEngine::U4DCallback<MobileLayer>;
    buttonBCallback->scheduleClassWithMethod(this, &MobileLayer::actionOnButtonB);
    buttonB->setCallbackAction(buttonBCallback);
    
    addChild(joystick);
    addChild(buttonA);
    addChild(buttonB);
    
}

void MobileLayer::setPlayer(Player *uPlayer){
    
    pPlayer=uPlayer;

}

//method called whenever you press button A
void MobileLayer::actionOnButtonA(){
    
    if (pPlayer!=nullptr) {
    
        U4DEngine::U4DVector3n forceDir=pPlayer->getViewInDirection();
        
        forceDir.y=0.0;
        
        forceDir.normalize();
        
        if (buttonA->getIsPressed()) {
            
            //move player forward
            pPlayer->setForceDirection(forceDir);
            
            if(pPlayer->getState()!=patrol){
                pPlayer->changeState(patrol);
            }
            
            
        }else if (buttonA->getIsReleased()){
            
            //stop player
            if (pPlayer->getState()!=patrolidle) {
                pPlayer->changeState(patrolidle);
            }
        }
        
    }
}

//method called whenever you press button B
void MobileLayer::actionOnButtonB(){
    
    if (pPlayer!=nullptr) {
    
        U4DEngine::U4DVector3n forceDir=pPlayer->getViewInDirection();
        
        forceDir.y=0.0;
        
        forceDir.normalize();
        
        //go backwards. reverse direction
        forceDir*=-1.0;
        
        if (buttonB->getIsPressed()) {
            
            //move player forward
            pPlayer->setForceDirection(forceDir);
            
            if(pPlayer->getState()!=patrol){
                pPlayer->changeState(patrol);
            }
            
            
        }else if (buttonB->getIsReleased()){
            
            //stop player
            if (pPlayer->getState()!=patrolidle) {
                pPlayer->changeState(patrolidle);
            }
        }
        
    }
    
    
}

//method called whenever you move the joystick
void MobileLayer::actionOnJoystick(){
    
    if(pPlayer!=nullptr){
        
        if (joystick->getIsActive()) {
            
            //Get the direction of the joystick
            U4DEngine::U4DVector2n joystickDirection=joystick->getDataPosition();
            
            U4DEngine::U4DVector3n joystickDirection3d(joystickDirection.x,joystickDirection.y,0.0);
            
            
            //get the view direction of the character
            U4DEngine::U4DVector3n v=pPlayer->getEntityForwardVector();
            
            //normalize the view direction
            v.normalize();
            
            //set up vector
            U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
            
            U4DEngine::U4DVector3n posDir=v.cross(upVector);
            
            //get angle between the joystick direction and the view direction
            float angle=v.angle(joystickDirection3d);
            
            //If the dot product between the joystick direction and the posDir less than zero, flip the angle
            if (joystickDirection3d.dot(posDir)<0.0) {
                angle*=-1.0;
            }
            
            //create a quaternion
            U4DEngine::U4DQuaternion newPlayerOrientation(angle, upVector);
            
            //Get current orientation for the character
            U4DEngine::U4DQuaternion currentPlayerOrientation=pPlayer->getAbsoluteSpaceOrientation();
            
            //Compute the slerp interpolation
            U4DEngine::U4DQuaternion p=currentPlayerOrientation.slerp(newPlayerOrientation, 1.0);
            
            //rotate the character
            pPlayer->rotateBy(p);
            
        }else{
            
            
        }
        
    }
    
    
}
