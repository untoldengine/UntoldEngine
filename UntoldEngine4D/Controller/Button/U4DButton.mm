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

namespace U4DEngine {
    
U4DButton::U4DButton(float xPosition,float yPosition,float uWidth,float uHeight,const char* uButtonImage1,const char* uButtonImage2,U4DCallbackInterface *uAction,TOUCHSTATE uButtonActionOn):buttonState(rTouchesNull){
    
    buttonImages.setImages(uButtonImage1,uButtonImage2,uWidth,uHeight);
    
    U4DVector3n translation(xPosition,yPosition,0.0);
    
    translateTo(translation);     //move the button
    
    buttonImages.translateTo(translation);  //move the image
    
    
    //set the callback
    pCallback=uAction;
    
    //set where to do the action on the button
    buttonActionOn=uButtonActionOn;
    
    //get the coordinates of the box
    centerPosition=getLocalPosition();
    
    U4DDirector *director=U4DDirector::sharedInstance();
    
    left=centerPosition.x-uWidth/director->getDisplayWidth();
    right=centerPosition.x+uWidth/director->getDisplayWidth();
    
    top=centerPosition.y+uHeight/director->getDisplayHeight();
    bottom=centerPosition.y-uHeight/director->getDisplayHeight();
    
};

void U4DButton::draw(){
    
    buttonImages.draw();

}

void U4DButton::update(float dt){
    
    if (getState()==getButtonActionOn()) {
        
        action();
        
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

               buttonState=uTouchState;
               
               if (buttonState==rTouchesBegan || buttonState==rTouchesMoved) {
                
                   buttonImages.changeImage();
                   
               }else if (buttonState==rTouchesEnded){
                   
                   buttonImages.changeImage();  //select default image
                   
               }
            }
        }

}

TOUCHSTATE U4DButton::getState(){
    return buttonState;
}

void U4DButton::setButtonActionOn(TOUCHSTATE &uButtonActionOn){
    
    buttonActionOn=uButtonActionOn;
}

TOUCHSTATE U4DButton::getButtonActionOn(){
    
    return buttonActionOn;
}

}
