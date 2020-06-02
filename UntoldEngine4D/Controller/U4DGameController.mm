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
#include "U4DGameModelInterface.h"
#include "U4DLayer.h"
#include "U4DEntity.h"
#include "U4DLayerManager.h"

namespace U4DEngine {

    U4DGameController::U4DGameController():receivedAction(false){
        
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

    void U4DGameController::setGameModel(U4DGameModelInterface *uGameModel){
        
        gameModel=uGameModel;
        
    }

    U4DWorld* U4DGameController::getGameWorld(){
        
        return gameWorld;
    }

    U4DGameModelInterface* U4DGameController::getGameModel(){
        
        return gameModel;
    }

    void U4DGameController::sendUserInputUpdate(void *uData){
        
        U4DLayerManager *layerManager=U4DLayerManager::sharedInstance();
        
        U4DLayer *activeLayer=layerManager->getActiveLayer(); 
        
        CONTROLLERMESSAGE controllerInputMessage=*(CONTROLLERMESSAGE*)uData;
        
        U4DEngine::INPUTELEMENTACTION inputAction=static_cast<U4DEngine::INPUTELEMENTACTION>(controllerInputMessage.inputElementAction);
        
        bool handleByUIElement=false;
        
        //Go through the layer's children and check if the input coordinates lie within their boundaries
        if (activeLayer!=nullptr) {
            
            U4DEntity *child=activeLayer->getLastChild();
            
            while (child!=nullptr) {
                
                if(child->changeState(inputAction, controllerInputMessage.inputPosition)){
                    
                    //Message will be handle by the element callback
                    handleByUIElement=true;
                    
                    break;
                }
                
                child=child->getPrevSibling();
                
            }
            
        }
        
        if (!handleByUIElement) {
            gameModel->receiveUserInputUpdate(&controllerInputMessage);
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
