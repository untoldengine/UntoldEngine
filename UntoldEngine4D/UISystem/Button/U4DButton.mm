//
//  U4DButton.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/11/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DButton.h"
#include "Constants.h"
#include "U4DVector2n.h"
#include "U4DDirector.h"
#include "U4DControllerInterface.h"
#include "U4DNumerical.h"
#include "U4DSceneManager.h"
#include "U4DText.h"

namespace U4DEngine {
    
U4DButton::U4DButton(std::string uName, float xPosition,float yPosition,float uWidth,float uHeight, std::string uLabel, std::string uFontData):U4DShaderEntity(1.0){
    
    initButtonProperties(uName,xPosition,yPosition,uWidth,uHeight);
    
    //add text
    labelText=new U4DEngine::U4DText(uFontData); 

    labelText->setText(uLabel.c_str());
    
    loadRenderingInformation();
    
    addChild(labelText);
    
    U4DVector3n pos=getAbsolutePosition();
    
    labelText->translateBy(left-centerPosition.x+U4DEngine::uiPadding,0.0,0.0);
    
}

U4DButton::U4DButton(std::string uName, float xPosition,float yPosition,float uWidth,float uHeight,const char* uButtonImage):U4DShaderEntity(1.0){
    
    
    initButtonProperties(uName,xPosition,yPosition,uWidth,uHeight);
    
    setTexture0(uButtonImage);
    
    setEnableAdditiveRendering(false);
    
    loadRenderingInformation();
    
}

void U4DButton::initButtonProperties(std::string uName, float xPosition,float yPosition,float uWidth,float uHeight){
    
    
    pCallback=nullptr;
    
    controllerInterface=nullptr;
    
    currentPosition=U4DVector2n(0.0,0.0);
    
    setName(uName);
    
    //set controller
    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
    
    controllerInterface=sceneManager->getGameController();
    
    setShader("vertexUIButtonShader", "fragmentUIButtonShader");
    
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
    setState(U4DEngine::uipressed);
    
}
    
U4DButton::~U4DButton(){
    
    delete labelText;
    
}

void U4DButton::update(double dt){

}

void U4DButton::action(){
    
    CONTROLLERMESSAGE controllerMessage;
    
    controllerMessage.elementUIName=getName();
    
    controllerMessage.inputElementType=U4DEngine::uiButton;

    U4DVector4n param(0.0,0.0,0.0,0.0);
    
    if (getIsPressed()) {
        
        param=U4DVector4n(1.0,0.0,0.0,0.0);
        
        controllerMessage.inputElementAction=U4DEngine::uiButtonPressed;

    }else if(getIsReleased()){
        
        controllerMessage.inputElementAction=U4DEngine::uiButtonReleased;

    }
    
    updateShaderParameterContainer(0, param);
    
    if(pCallback!=nullptr){
        
        pCallback->action();
        
    }else{
        
        controllerInterface->getGameModel()->receiveUserInputUpdate(&controllerMessage);
    
    }

}

void U4DButton::changeState(int uState){
    
    previousState=state;
    
    //set new state
    setState(uState);
    
    switch (uState) {
         
         case U4DEngine::uipressed:
            
            action();
            
            break;
            
        case U4DEngine::uireleased:
            
            action();
            
            break;
            
            
        default:
            break;
    }
    
    
}

int U4DButton::getState(){
    
    return state;
    
}

void U4DButton::setState(int uState){
    state=uState;
}


bool U4DButton::changeState(INPUTELEMENTACTION uInputAction, U4DVector2n uPosition){
    
    bool withinBoundary=false;
    
    if (uPosition.x>left && uPosition.x<right) {
        
        if (uPosition.y>bottom && uPosition.y<top) {

            currentPosition=uPosition;
            
            withinBoundary=true;
            
            if (uInputAction==U4DEngine::mouseButtonPressed || uInputAction==U4DEngine::ioTouchesBegan) {
                
                changeState(U4DEngine::uipressed);
                
                
            }else if((uInputAction==U4DEngine::mouseButtonDragged || uInputAction==U4DEngine::ioTouchesMoved) && (getState()==U4DEngine::uipressed)){
                
                changeState(U4DEngine::uimoving);
                
                
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
    
void U4DButton::setCallbackAction(U4DCallbackInterface *uAction){
    
    //set the callback
    pCallback=uAction;
    
}
    
bool U4DButton::getIsPressed(){
    
    return (getState()==U4DEngine::uipressed);
    
}

bool U4DButton::getIsReleased(){
    
    return (getState()==U4DEngine::uireleased);
    
} 
    

}
