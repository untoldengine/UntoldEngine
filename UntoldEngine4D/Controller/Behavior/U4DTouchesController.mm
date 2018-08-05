//
//  U4DTouchesController.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DTouchesController.h"
#include "U4DGameModelInterface.h"
#include "U4DVector2n.h"
#include "U4DButton.h"
#include "U4DJoyStick.h"
#include "U4DWorld.h"

namespace U4DEngine {
    
//constructor
U4DTouchesController::U4DTouchesController():receivedAction(false){}

//destructor
U4DTouchesController::~U4DTouchesController(){}
    
void U4DTouchesController::setGameWorld(U4DWorld *uGameWorld){
    
    gameWorld=uGameWorld;

}


void U4DTouchesController::setGameModel(U4DGameModelInterface *uGameModel){
    
    gameModel=uGameModel;

}
    
U4DWorld* U4DTouchesController::getGameWorld(){

    return gameWorld;
}

U4DGameModelInterface* U4DTouchesController::getGameModel(){
    
    return gameModel;
}
    
    
void U4DTouchesController::touchBegan(const U4DTouches &touches){
    
    U4DEngine::TOUCHSTATE touchBegan=U4DEngine::rTouchesBegan;
    
    changeState(touches, touchBegan);
}

void U4DTouchesController::touchMoved(const U4DTouches &touches){
 
    U4DEngine::TOUCHSTATE touchMoved=U4DEngine::rTouchesMoved;
    
    changeState(touches, touchMoved);
    
}

void U4DTouchesController::touchEnded(const U4DTouches &touches){
    
    U4DEngine::TOUCHSTATE touchEnded=U4DEngine::rTouchesEnded;
    
    changeState(touches, touchEnded);
}

void U4DTouchesController::changeState(const U4DTouches &touches,TOUCHSTATE &touchState){
    
    U4DVector3n touchPosition(touches.xTouch,touches.yTouch,0.0);
    
    U4DEntity *child=gameWorld;
    
    //change the state of the controller input
    while (child!=NULL) {
        
        if (child->getEntityType()==CONTROLLERINPUT) {
            
            child->changeState(touchState,touchPosition);
        
        }
        
        child=child->next;
        
    }
    
}
    
void U4DTouchesController::sendUserInputUpdate(void *uData){

    gameModel->receiveUserInputUpdate(uData);
}
    
void U4DTouchesController::setReceivedAction(bool uValue){

    receivedAction=uValue;
}

}
