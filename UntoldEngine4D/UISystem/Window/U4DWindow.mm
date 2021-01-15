//
//  U4DWindow.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/24/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DWindow.h"
#include "Constants.h"
#include "U4DVector2n.h"
#include "U4DDirector.h"
#include "U4DControllerInterface.h"
#include "U4DNumerical.h"
#include "U4DSceneManager.h"
#include "U4DText.h"

namespace U4DEngine {
    
U4DWindow::U4DWindow(std::string uName, float xPosition,float yPosition,float uWidth,float uHeight, std::string uLabel, std::string uFontData):U4DShaderEntity(1.0),pCallback(NULL),controllerInterface(NULL),currentPosition(0.0,0.0),dataValue(0.0){
    
    setName(uName);
    
    //set controller
    //Get the touch controller
    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
    
    controllerInterface=sceneManager->getGameController();
    
    //setShader("vertexUIWindowShader", "fragmentUIWindowShader");
    
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
    
    setEnableAdditiveRendering(false);
    
    loadRenderingInformation();
    
    addChild(labelText);
    
    U4DVector3n pos=getAbsolutePosition();
    
    labelText->translateTo(left+U4DEngine::uiPadding,top-U4DEngine::uiPadding,0.0);
    //labelText->translateBy(left/2.0+5.0*U4DEngine::uiPadding,top/2.0+3.0*U4DEngine::uiPadding,0.0);

}
    
U4DWindow::~U4DWindow(){
    
    delete labelText;
}


void U4DWindow::update(double dt){

}

void U4DWindow::action(){
    
    

}

void U4DWindow::changeState(int uState){
    
    previousState=state;
    
    //set new state
    setState(uState);
    
    switch (uState) {
         
         case U4DEngine::uipressed:
            
            dataValue=!dataValue;
            
            
            break;
            
        case U4DEngine::uireleased:
            
            
            break;

            
        default:
            break;
    }
    
    
}

int U4DWindow::getState(){
    
    return state;
    
}

void U4DWindow::setState(int uState){
    state=uState;
}

bool U4DWindow::changeState(INPUTELEMENTACTION uInputAction, U4DVector2n uPosition){
    
    bool withinBoundary=false;
    
    if (uPosition.x>left && uPosition.x<right) {
    
        if (uPosition.y>bottom && uPosition.y<top) {
         
            withinBoundary=true;
            
            U4DEntity *child=this->getLastChild();
            
            while (child!=nullptr) {
                
                
                child=child->getPrevSibling();
                
            }
            
        }
        
    }
    
    return withinBoundary;
    
}
    
void U4DWindow::setCallbackAction(U4DCallbackInterface *uAction){
    
    //set the callback
    pCallback=uAction;
    
}
    
bool U4DWindow::getIsPressed(){
    
    return (getState()==U4DEngine::uipressed);
    
}

bool U4DWindow::getIsReleased(){
    
    return (getState()==U4DEngine::uireleased);
    
}

bool U4DWindow::getIsActive(){
    
    return (getState()==U4DEngine::uimoving);
    
}
    

}
