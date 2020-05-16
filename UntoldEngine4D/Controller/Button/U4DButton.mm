//
//  U4DButton.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/11/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DButton.h"
#include "U4DVector2n.h"
#include "U4DDirector.h"
#include "U4DControllerInterface.h"
#include "U4DButtonPressedState.h"
#include "U4DButtonReleasedState.h"
#include "U4DButtonIdleState.h"
#include "U4DButtonMovedState.h"
#include "U4DButtonStateManager.h"
#include "U4DNumerical.h"

namespace U4DEngine {
    
U4DButton::U4DButton(std::string uName, float xPosition,float yPosition,float uWidth,float uHeight,const char* uButtonImage1,const char* uButtonImage2):controllerInterface(NULL),pCallback(NULL),currentTouchPosition(0.0,0.0,0.0){
    
    stateManager=new U4DButtonStateManager(this);
    
    setName(uName);
    
    setEntityType(CONTROLLERINPUT);
    
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
    
    //set initial state
    stateManager->changeState(U4DButtonIdleState::sharedInstance());
    
}
    
U4DButton::~U4DButton(){
    
    delete stateManager;
    
}

void U4DButton::render(id <MTLRenderCommandEncoder> uRenderEncoder){
    
    buttonImages.render(uRenderEncoder);

}

void U4DButton::update(double dt){
    
    stateManager->update(dt);
    
}

void U4DButton::action(){
    
    pCallback->action();

}

void U4DButton::changeState(TOUCHSTATE uTouchState,U4DVector3n &uTouchPosition){
    
    
    if (uTouchPosition.x>left && uTouchPosition.x<right) {
        
        if (uTouchPosition.y>bottom && uTouchPosition.y<top) {

            currentTouchPosition=uTouchPosition;
            
            if (uTouchState==rTouchesBegan) {
                
                stateManager->changeState(U4DButtonPressedState::sharedInstance());
            
            }else if(uTouchState==rTouchesMoved && (stateManager->getCurrentState()==U4DButtonPressedState::sharedInstance())){
                
                stateManager->changeState(U4DButtonMovedState::sharedInstance());
            
            }else if(uTouchState==rTouchesEnded && (stateManager->getCurrentState()==U4DButtonPressedState::sharedInstance() || stateManager->getCurrentState()==U4DButtonMovedState::sharedInstance())){
                
                stateManager->changeState(U4DButtonReleasedState::sharedInstance());
                
            }
        }
        
    }
    
    
    if (uTouchPosition.x<left || uTouchPosition.x>right || uTouchPosition.y<bottom || uTouchPosition.y>top ){
        
        if (stateManager->getCurrentState()==U4DButtonMovedState::sharedInstance()) {
            
            float touchDistance=(currentTouchPosition-uTouchPosition).magnitude();
        
            U4DNumerical numerical;
            
            if (numerical.areEqual(touchDistance, 0.0, buttonTouchEpsilon)) {
                
                stateManager->changeState(U4DButtonReleasedState::sharedInstance());
            }
            
        }
        
    }
    
    
}
    
void U4DButton::setCallbackAction(U4DCallbackInterface *uAction){
    
    //set the callback
    pCallback=uAction;
    
}
    
bool U4DButton::getIsPressed(){
    
    return (stateManager->getCurrentState()==U4DButtonPressedState::sharedInstance());
    
}

bool U4DButton::getIsReleased(){
    
    return (stateManager->getCurrentState()==U4DButtonReleasedState::sharedInstance());
    
}
    
void U4DButton::setControllerInterface(U4DControllerInterface* uControllerInterface){

    controllerInterface=uControllerInterface;
    
}
    

}
