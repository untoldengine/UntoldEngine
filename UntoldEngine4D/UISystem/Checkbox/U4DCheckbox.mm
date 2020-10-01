//
//  U4DCheckbox.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/23/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DCheckbox.h"
#include "Constants.h"
#include "U4DVector2n.h"
#include "U4DDirector.h"
#include "U4DControllerInterface.h"
#include "U4DNumerical.h"
#include "U4DSceneManager.h"
#include "U4DText.h"


namespace U4DEngine {
    
U4DCheckbox::U4DCheckbox(std::string uName, float xPosition,float yPosition,float uWidth,float uHeight, std::string uLabel, std::string uFontData):U4DShaderEntity(1.0),pCallback(NULL),controllerInterface(NULL),currentPosition(0.0,0.0),dataValue(0.0){
    
    setName(uName);
    
    //set controller
    //Get the touch controller
    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
    
    controllerInterface=sceneManager->getGameController();
    
    setShader("vertexUICheckboxShader", "fragmentUICheckboxShader");
    
    setShaderDimension(uWidth, uHeight);

    U4DVector2n translation(xPosition,yPosition);
    
    translateTo(translation);     //move the button
         
    //get the coordinates of the box
    centerPosition.x=getLocalPosition().x;
    centerPosition.y=getLocalPosition().y;
    
    U4DDirector *director=U4DDirector::sharedInstance();
    
    left=centerPosition.x-uWidth/director->getDisplayWidth();
    right=centerPosition.x+uWidth/director->getDisplayWidth();
    
    top=centerPosition.y+uHeight/director->getDisplayHeight();
    bottom=centerPosition.y-uHeight/director->getDisplayHeight();
    
    //set initial state
    setState(U4DEngine::uireleased);
    
    //add text
    
    labelText=new U4DEngine::U4DText(uFontData);

    labelText->setText(uLabel.c_str());
    
    loadRenderingInformation();
    
    addChild(labelText);
    
    U4DVector3n pos=getAbsolutePosition();
    
    labelText->translateTo(right+U4DEngine::uiPadding,pos.y,0.0);

}
    
U4DCheckbox::~U4DCheckbox(){
    
}


void U4DCheckbox::update(double dt){

}

void U4DCheckbox::action(){
    
    CONTROLLERMESSAGE controllerMessage;
    
    controllerMessage.elementUIName=getName();
    
    controllerMessage.inputElementType=U4DEngine::uiCheckbox;

    U4DVector4n param(dataValue,0.0,0.0,0.0);
    updateShaderParameterContainer(0, param);
    
    if (getIsPressed()) {
        
        controllerMessage.inputElementAction=U4DEngine::uiCheckboxPressed;

    }else if(getIsReleased()){
        
        controllerMessage.inputElementAction=U4DEngine::uiCheckboxReleased;

    }
    
    if (pCallback!=nullptr) {
        
        pCallback->action();
        
    }else{
        
        controllerInterface->getGameModel()->receiveUserInputUpdate(&controllerMessage);
    
    }

}

void U4DCheckbox::changeState(int uState){
    
    previousState=state;
    
    //set new state
    setState(uState);
    
    switch (uState) {
         
         case U4DEngine::uipressed:
            
            dataValue=!dataValue;
            
            action();
            
            break;
            
        case U4DEngine::uireleased:
            
            action();
            
            break;

            
        default:
            break;
    }
    
    
}

int U4DCheckbox::getState(){
    
    return state;
    
}

void U4DCheckbox::setState(int uState){
    state=uState;
}

bool U4DCheckbox::changeState(INPUTELEMENTACTION uInputAction, U4DVector2n uPosition){
    
    bool withinBoundary=false;
    
    if (uPosition.x>left && uPosition.x<right) {
        
        if (uPosition.y>bottom && uPosition.y<top) {
            
            currentPosition=uPosition;
            
            withinBoundary=true;
            
            if (uInputAction==U4DEngine::mouseButtonPressed || uInputAction==U4DEngine::ioTouchesBegan) {
                
                changeState(U4DEngine::uipressed);
                
            }else if((uInputAction==U4DEngine::mouseButtonReleased || uInputAction==U4DEngine::ioTouchesEnded) && (getState()==U4DEngine::uipressed || getState()==U4DEngine::uimoving)){
                
                changeState(U4DEngine::uireleased);
                
            }
        }
        
    }
    
    
    if (uPosition.x<left || uPosition.x>right || uPosition.y<bottom || uPosition.y>top ){
        
        if (getState()==U4DEngine::uimoving) {
            
            float touchDistance=(currentPosition-uPosition).magnitude();
        
            U4DNumerical numerical;
            
            if (numerical.areEqual(touchDistance, 0.0, buttonTouchEpsilon)) {
                
                changeState(U4DEngine::uireleased);
                
            }
            
        }
        
    }
    
    return withinBoundary;
    
}
    
void U4DCheckbox::setCallbackAction(U4DCallbackInterface *uAction){
    
    //set the callback
    pCallback=uAction;
    
}
    
bool U4DCheckbox::getIsPressed(){
    
    return (getState()==U4DEngine::uipressed);
    
}

bool U4DCheckbox::getIsReleased(){
    
    return (getState()==U4DEngine::uireleased);
    
}

bool U4DCheckbox::getIsActive(){
    
    return (getState()==U4DEngine::uimoving);
    
}
    

}
