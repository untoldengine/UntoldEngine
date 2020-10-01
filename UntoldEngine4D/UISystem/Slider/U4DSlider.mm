//
//  U4DSlider.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/21/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DSlider.h"
#include "Constants.h"
#include "U4DVector2n.h"
#include "U4DDirector.h"
#include "U4DControllerInterface.h"
#include "U4DNumerical.h"
#include "U4DSceneManager.h"

#include "U4DText.h"

namespace U4DEngine {
    
U4DSlider::U4DSlider(std::string uName, float xPosition,float yPosition,float uWidth,float uHeight, std::string uLabel, std::string uFontData):U4DShaderEntity(1.0),pCallback(NULL),controllerInterface(NULL),currentPosition(0.0,0.0),dataValue(0.0){
    
    setName(uName);
    
    //set controller
    //Get the touch controller
    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
    
    controllerInterface=sceneManager->getGameController();
    
    setShader("vertexUISliderShader", "fragmentUISliderShader");
    
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
    
    valueText=new U4DEngine::U4DText(uFontData);

    valueText->setText(0.0);

    loadRenderingInformation();
    
    addChild(labelText);
    addChild(valueText);
    
    U4DVector3n pos=getAbsolutePosition();
    
    labelText->translateTo(right+U4DEngine::uiPadding,pos.y,0.0);
    valueText->translateTo(left,bottom-U4DEngine::uiPadding, 0.0);

}
    
U4DSlider::~U4DSlider(){
    
}


void U4DSlider::update(double dt){

    if(state==U4DEngine::uimoving){
        
        U4DVector2n sliderPosition=(currentPosition-centerPosition)*(1.0/getShaderWidth());
        
        dataValue=sliderPosition.x;
        
        valueText->setText(dataValue);
        
        U4DVector4n param(sliderPosition.x,0.0,0.0,0.0);
        
        updateShaderParameterContainer(0, param);
        
        action();
    }

}

void U4DSlider::action(){
    
    CONTROLLERMESSAGE controllerMessage;
    
    controllerMessage.elementUIName=getName();
    
    controllerMessage.inputElementType=U4DEngine::uiSlider;

    controllerMessage.dataValue=dataValue;
    
    U4DVector4n param(0.0,0.0,0.0,0.0);
    
    if (getIsPressed()) {
        
        param=U4DVector4n(1.0,0.0,0.0,0.0);
        updateShaderParameterContainer(0, param);
        controllerMessage.inputElementAction=U4DEngine::uiSliderPressed;

    }else if(getIsReleased()){
        
        updateShaderParameterContainer(0, param);
        controllerMessage.inputElementAction=U4DEngine::uiSliderReleased;

    }else if(getIsActive()){
        
        controllerMessage.inputElementAction=U4DEngine::uiSliderMoved;

    }
    
    if (pCallback!=nullptr) {
        
        pCallback->action();
        
    }else{
        
        controllerInterface->getGameModel()->receiveUserInputUpdate(&controllerMessage);
    
    }

}

void U4DSlider::changeState(int uState){
    
    previousState=state;
    
    //set new state
    setState(uState);
    
    switch (uState) {
         
         case U4DEngine::uipressed:
            
            //action();
            
            break;
            
        case U4DEngine::uireleased:
            
            //action();
            
            break;
            
        case U4DEngine::uimoving:
            
            break;
            
        default:
            break;
    }
    
    
}

int U4DSlider::getState(){
    
    return state;
    
}

void U4DSlider::setState(int uState){
    state=uState;
}

bool U4DSlider::changeState(INPUTELEMENTACTION uInputAction, U4DVector2n uPosition){
    
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
    
void U4DSlider::setCallbackAction(U4DCallbackInterface *uAction){
    
    //set the callback
    pCallback=uAction;
    
}
    
bool U4DSlider::getIsPressed(){
    
    return (getState()==U4DEngine::uipressed);
    
}

bool U4DSlider::getIsReleased(){
    
    return (getState()==U4DEngine::uireleased);
    
}

bool U4DSlider::getIsActive(){
    
    return (getState()==U4DEngine::uimoving);
    
}
    

}
