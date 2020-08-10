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
#include "U4DSceneManager.h"


namespace U4DEngine {
    
U4DButton::U4DButton(std::string uName, float xPosition,float yPosition,float uWidth,float uHeight,const char* uButtonImage1,const char* uButtonImage2):pCallback(NULL),controllerInterface(NULL),currentTouchPosition(0.0,0.0){
    
    stateManager=new U4DButtonStateManager(this);
    
    setName(uName);
    
    //set controller
    //Get the touch controller
    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
    
    controllerInterface=sceneManager->getGameController();
    
    setEntityType(CONTROLLERINPUT);
    
    buttonImages.setImage(uButtonImage1,uButtonImage2,uWidth,uHeight);
    
    U4DVector2n translation(xPosition,yPosition);
    
    translateTo(translation);     //move the button
    
    buttonImages.translateTo(translation);  //move the image
    
    //get the coordinates of the box
    centerPosition.x=getLocalPosition().x;
    centerPosition.y=getLocalPosition().y;
    
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
    
    CONTROLLERMESSAGE controllerMessage;
    
    controllerMessage.elementUIName=getName();
    
    controllerMessage.inputElementType=U4DEngine::uiButton;

    if (getIsPressed()) {

        controllerMessage.inputElementAction=U4DEngine::uiButtonPressed;

    }else if(getIsReleased()){

        controllerMessage.inputElementAction=U4DEngine::uiButtonReleased;

    }

    controllerInterface->sendUserInputUpdate(&controllerMessage);

}

bool U4DButton::changeState(INPUTELEMENTACTION uInputAction, U4DVector2n uPosition){
    
    bool withinBoundary=false;
    
    if (uPosition.x>left && uPosition.x<right) {
        
        if (uPosition.y>bottom && uPosition.y<top) {

            currentTouchPosition=uPosition;
            
            withinBoundary=true;
            
            if (uInputAction==U4DEngine::mouseButtonPressed || uInputAction==U4DEngine::ioTouchesBegan) {
                
                stateManager->changeState(U4DButtonPressedState::sharedInstance());
            
            }else if((uInputAction==U4DEngine::mouseButtonDragged || uInputAction==U4DEngine::ioTouchesMoved) && (stateManager->getCurrentState()==U4DButtonPressedState::sharedInstance())){
                
                stateManager->changeState(U4DButtonMovedState::sharedInstance());
            
            }else if((uInputAction==U4DEngine::mouseButtonReleased || uInputAction==U4DEngine::ioTouchesEnded) && (stateManager->getCurrentState()==U4DButtonPressedState::sharedInstance() || stateManager->getCurrentState()==U4DButtonMovedState::sharedInstance())){
                
                stateManager->changeState(U4DButtonReleasedState::sharedInstance());
                
            }
        }
        
    }
    
    
    if (uPosition.x<left || uPosition.x>right || uPosition.y<bottom || uPosition.y>top ){
        
        if (stateManager->getCurrentState()==U4DButtonMovedState::sharedInstance()) {
            
            float touchDistance=(currentTouchPosition-uPosition).magnitude();
        
            U4DNumerical numerical;
            
            if (numerical.areEqual(touchDistance, 0.0, buttonTouchEpsilon)) {
                
                stateManager->changeState(U4DButtonReleasedState::sharedInstance());
            }
            
        }
        
    }
    
    return withinBoundary;
    
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
    

}
