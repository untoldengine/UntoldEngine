//
//  Touches.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/9/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DTouches.h"
#include "U4DTouchesStateInterface.h"
#include "U4DTouchesStateManager.h"
#include "U4DTouchesIdleState.h"
#include "U4DTouchesPressedState.h"
#include "U4DTouchesReleasedState.h"
#include "U4DTouchesMovedState.h"
#include "U4DControllerInterface.h"
#include "U4DDirector.h"

namespace U4DEngine {
    
    U4DTouches::U4DTouches(INPUTELEMENTTYPE uInputElementType, U4DControllerInterface* uControllerInterface):U4DInputElement(uInputElementType,uControllerInterface){
        
        stateManager=new U4DTouchesStateManager(this);
        
        //set initial state
        stateManager->changeState(U4DTouchesIdleState::sharedInstance());
        
    }
    
    U4DTouches::~U4DTouches(){
        
        delete stateManager;
        
    }

    void U4DTouches::setDataPosition(U4DVector2n uDataPosition){
        
        dataPosition=uDataPosition;
    }
        
    U4DVector2n U4DTouches::getDataPosition(){
        
        return dataPosition;
    }

    void U4DTouches::update(double dt){
        
        stateManager->update(dt);
        
    }
    
    void U4DTouches::action(){
        
        CONTROLLERMESSAGE controllerMessage;
        
        controllerMessage.inputElementType=inputElementType;
        
        if (getIsPressed()) {
    
            controllerMessage.inputElementAction=U4DEngine::ioTouchesBegan;
    
        }else if(getIsReleased()){
    
            controllerMessage.inputElementAction=U4DEngine::ioTouchesEnded;
    
        }else if (getIsMoving()){
            
            controllerMessage.inputElementAction=U4DEngine::ioTouchesMoved;
            
        }
        
        controllerMessage.touchPosition=dataPosition;
        
        controllerInterface->sendUserInputUpdate(&controllerMessage);
        
    }

    void U4DTouches::changeState(INPUTELEMENTACTION &uInputAction, U4DVector2n &uPosition){
        
        //map the location of the mouse cursor to the right space
        U4DDirector *director=U4DDirector::sharedInstance();
        
        float height=director->getDisplayHeight();
        float width=director->getDisplayWidth();
        
        uPosition.x=(uPosition.x-width/2)/(width/2);
        uPosition.y=(height/2-uPosition.y)/(height/2);
        
        if (uInputAction==U4DEngine::ioTouchesBegan) {
        
            dataPosition=uPosition;
            
            stateManager->changeState(U4DTouchesPressedState::sharedInstance());
            
        }else if (uInputAction==U4DEngine::ioTouchesEnded){
            
            dataPosition=uPosition;
            
            stateManager->changeState(U4DTouchesReleasedState::sharedInstance());
            
        }else if (uInputAction==U4DEngine::ioTouchesMoved){
            
            dataPosition=uPosition;
            
            stateManager->changeState(U4DTouchesMovedState::sharedInstance());
            
        }

            
    }

    bool U4DTouches::getIsMoving(){
        
        return (stateManager->getCurrentState()==U4DTouchesMovedState::sharedInstance());
        
    }
        
    bool U4DTouches::getIsPressed(){
        
        return (stateManager->getCurrentState()==U4DTouchesPressedState::sharedInstance());
        
    }
        
    bool U4DTouches::getIsReleased(){
        
        return (stateManager->getCurrentState()==U4DTouchesReleasedState::sharedInstance());
        
    }
    
}
