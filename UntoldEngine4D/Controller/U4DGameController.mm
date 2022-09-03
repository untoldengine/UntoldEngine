//
//  U4DGameController.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/6/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DGameController.h"
#include "U4DInputElement.h"
#include "U4DWorld.h"
#include "U4DGameLogicInterface.h"
#include "U4DSceneManager.h"
#include "U4DSceneStateManager.h"
#include "U4DScenePlayState.h"

namespace U4DEngine {

    U4DGameController::U4DGameController():receivedAction(false),gameWorld(nullptr),gameLogic(nullptr){
        
    }
        
    U4DGameController::~U4DGameController(){
        
    }

    void U4DGameController::update(double dt){
        
        for (const auto &n : inputElementContainer) {
            
            n->update(dt);
            
        }
        
    }
        
    void U4DGameController::registerInputEntity(U4DInputElement *uInputElement){
        
        inputElementContainer.push_back(uInputElement);
        
    }
        
    void U4DGameController::removeInputEntity(U4DInputElement *uInputElement){
        
    }
        
    void U4DGameController::notifyInputEntity(){
        
    }
        
    void U4DGameController::changeState(INPUTELEMENTTYPE uInputElement, INPUTELEMENTACTION uInputAction, U4DVector2n &uPosition){
        
        for (const auto &n : inputElementContainer) {
            
            if (n->getInputElementType()==uInputElement) {
                
                n->changeState(uInputAction, uPosition);
                

            }
            
            
        }
        
    }

    void U4DGameController::setGameWorld(U4DWorld *uGameWorld){
        
        gameWorld=uGameWorld;
        
    }

    void U4DGameController::setGameLogic(U4DGameLogicInterface *uGameLogic){
        
        gameLogic=uGameLogic;
        
    }

    U4DWorld* U4DGameController::getGameWorld(){
        
        return gameWorld;
    }

    U4DGameLogicInterface* U4DGameController::getGameLogic(){
        
        return gameLogic;
    }

    void U4DGameController::sendUserInputUpdate(void *uData){
        
        U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
        U4DScene *scene=sceneManager->getCurrentScene();
        U4DSceneStateManager *sceneStateManager=scene->getSceneStateManager();
        
        //need to add this check for ios devices
        if(gameWorld!=nullptr && gameLogic!=nullptr){
            
            //Send the user input to the MVC components.
            gameWorld->receiveUserInputUpdate(uData);
            
            //if the scene is in play scene, then accept user inputs
            if(sceneStateManager->getCurrentState()==U4DScenePlayState::sharedInstance()){
                gameLogic->receiveUserInputUpdate(uData);
            }
            
        }
        
    }

    void U4DGameController::setReceivedAction(bool uValue){
        
        receivedAction=uValue;
    }

    void U4DGameController::getUserInputData(INPUTELEMENTTYPE uInputElement, INPUTELEMENTACTION uInputAction, U4DVector2n &uPosition){
        
        changeState(uInputElement, uInputAction, uPosition);
        
    }

    void U4DGameController::getUserInputData(INPUTELEMENTTYPE uInputElement, INPUTELEMENTACTION uInputAction){
        
        U4DVector2n pos(0.0,0.0);
        
        getUserInputData(uInputElement,uInputAction, pos);
        
        
    }
    
}
