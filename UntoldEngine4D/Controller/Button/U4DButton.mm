//
//  U4DButton.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DButton.h"
#include "U4DVector2n.h"
#include "U4DTouches.h"
#include "U4DDirector.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {
    
U4DButton::U4DButton(std::string uName, float xPosition,float yPosition,float uWidth,float uHeight,const char* uButtonImage1,const char* uButtonImage2):buttonState(rTouchesNull),isActive(false),controllerInterface(NULL),pCallback(NULL),receivedAction(false){
    
    setName(uName);
    
    buttonImages.setImage(uButtonImage1,uButtonImage2,uWidth,uHeight);
    
    U4DVector3n translation(xPosition,yPosition,0.0);
    
    translateTo(translation);     //move the button
    
    buttonImages.translateTo(translation);  //move the image
    
    //get the coordinates of the box
    centerPosition=getLocalPosition();
    
    U4DDirector *director=U4DDirector::sharedInstance();
    
    left=centerPosition.x-uWidth/director->getDisplayWidth();
    right=centerPosition.x+uWidth/director->getDisplayWidth();
    
    top=centerPosition.y+uHeight/director->getDisplayHeight();
    bottom=centerPosition.y-uHeight/director->getDisplayHeight();
    
};

void U4DButton::render(id <MTLRenderCommandEncoder> uRenderEncoder){
    
    buttonImages.render(uRenderEncoder);

}

void U4DButton::update(float dt){
    
    
    if (getState()!=rTouchesNull) {
        
        receivedAction=true;
        
        if (getState()==rTouchesBegan ) {
            
            isActive=true;
           
            
        }else if(getState()==rTouchesEnded){
            
            isActive=false;
           
        }
        
        if (pCallback!=NULL) {
            action();
        }
        
        
        if (controllerInterface !=NULL) {
            controllerInterface->setReceivedAction(true);
        }
       
        buttonState=rTouchesNull;
        
    }else{
        
        receivedAction=NULL;
        isActive=NULL;
        
    }
    
}

void U4DButton::action(){
    
    pCallback->action();

}

void U4DButton::changeState(TOUCHSTATE uTouchState){
    
    buttonState=uTouchState;
}

void U4DButton::changeState(TOUCHSTATE uTouchState,U4DVector3n uTouchPosition){
    
    
        if (uTouchPosition.x>left && uTouchPosition.x<right) {
            
           if (uTouchPosition.y>bottom && uTouchPosition.y<top) {

               if (uTouchState==rTouchesBegan || uTouchState==rTouchesEnded) {
                
                   buttonState=uTouchState;
                   buttonImages.changeImage();
                   
               }
            }
        }

}

TOUCHSTATE U4DButton::getState(){
    return buttonState;
}
    
void U4DButton::setCallbackAction(U4DCallbackInterface *uAction){
    
    //set the callback
    pCallback=uAction;
    
}
   
bool U4DButton::getIsActive(){

    return isActive;
}
    
bool U4DButton::getReceivedAction(){
    return receivedAction;
}
    
bool U4DButton::getIsPressed(){
    return (getReceivedAction()==true && getIsActive()==true);
}

bool U4DButton::getIsReleased(){
    return (getReceivedAction()==true && getIsActive()==false);
}
    
void U4DButton::setControllerInterface(U4DControllerInterface* uControllerInterface){

    controllerInterface=uControllerInterface;
    
}
    

}
