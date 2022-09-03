//
//  U4DGameLogic.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DGameLogic.h"
#include "U4DEntity.h"
#include "U4DEntityManager.h"
#include "U4DWorld.h"

namespace U4DEngine {

    void U4DGameLogic::setGameEntityManager(U4DEntityManager *uGameEntityManager){
        
        gameEntityManager=uGameEntityManager;
    }

    void U4DGameLogic::notify(U4DWorld *uGameWorld){
        
        
    }

    void U4DGameLogic::notify(U4DControllerInterface *uGameController){
        
    }

    void U4DGameLogic::setGameWorld(U4DWorld *uGameWorld){
        gameWorld=uGameWorld;
    }
    
    void U4DGameLogic::setGameController(U4DControllerInterface *uGameController){
        gameController=uGameController;
    }
    
    U4DEntity* U4DGameLogic::searchChild(std::string uName){
        
        return gameWorld->searchChild(uName);
    }
    
    U4DWorld* U4DGameLogic::getGameWorld(){
        
        return gameWorld;
    }
    
    U4DControllerInterface* U4DGameLogic::getGameController(){
        
        return gameController;
    }
    
    U4DEntityManager* U4DGameLogic::getGameEntityManager(){
        
        return gameEntityManager;
    
    }

    bool U4DGameLogic::isMouseLeftButtonPressed(void *uData){
        
        CONTROLLERMESSAGE controllerInputMessage=*(CONTROLLERMESSAGE*)uData;
        
        //4. If button was pressed
        if (controllerInputMessage.inputElementAction==U4DEngine::mouseLeftButtonPressed) {

            
            return true;
        }
        
        return false;
    }

    bool U4DGameLogic::isMouseLeftButtonReleased(void *uData){
        
        CONTROLLERMESSAGE controllerInputMessage=*(CONTROLLERMESSAGE*)uData;
        
        //4. If button was pressed
        if (controllerInputMessage.inputElementAction==U4DEngine::mouseLeftButtonReleased) {

            
            return true;
        }
        
        return false;
    }

    bool U4DGameLogic::isMouseRightButtonPressed(void *uData){
        
        CONTROLLERMESSAGE controllerInputMessage=*(CONTROLLERMESSAGE*)uData;
        
        //4. If button was pressed
        if (controllerInputMessage.inputElementAction==U4DEngine::mouseRightButtonPressed) {

            
            return true;
        }
        
        return false;
        
    }

    bool U4DGameLogic::isMouseRightButtonReleased(void *uData){
        
        CONTROLLERMESSAGE controllerInputMessage=*(CONTROLLERMESSAGE*)uData;
        
        //4. If button was pressed
        if (controllerInputMessage.inputElementAction==U4DEngine::mouseRightButtonReleased) {

            
            return true;
        }
        
        return false;
        
    }

    bool U4DGameLogic::isKeyPressed(int uKey, void *uData){
        
        CONTROLLERMESSAGE controllerInputMessage=*(CONTROLLERMESSAGE*)uData;
        
        if (controllerInputMessage.inputElementType==uKey && controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
            
            return true;
        }
        
        return false;
    }

    bool U4DGameLogic::isKeyReleased(int uKey, void *uData){
        
        CONTROLLERMESSAGE controllerInputMessage=*(CONTROLLERMESSAGE*)uData;
        
        if (controllerInputMessage.inputElementType==uKey && controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased) {
            
            return true;
        }
        
        return false;
        
    }

    bool U4DGameLogic::isMouseActive(void *uData){
        
        CONTROLLERMESSAGE controllerInputMessage=*(CONTROLLERMESSAGE*)uData;
        
        if(controllerInputMessage.inputElementAction==U4DEngine::mouseActive){
            
            
            
            return true;
        }
        
        return false;
    }

    bool U4DGameLogic::isMouseActiveDelta(void *uData){
        
        CONTROLLERMESSAGE controllerInputMessage=*(CONTROLLERMESSAGE*)uData;
        
        if(controllerInputMessage.inputElementAction==U4DEngine::mouseActiveDelta){
            
            
            
            return true;
        }
        
        return false;
        
    }

    bool U4DGameLogic::isGamePadButtonPressed(int uKey, void *uData){
        
        CONTROLLERMESSAGE controllerInputMessage=*(CONTROLLERMESSAGE*)uData;
        
        if(controllerInputMessage.inputElementType==uKey && controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed){
            
            
            return true;
            
        }
        
        return false;
    }

    bool U4DGameLogic::isGamePadButtonReleased(int uKey, void *uData){
        
        CONTROLLERMESSAGE controllerInputMessage=*(CONTROLLERMESSAGE*)uData;
        
        if(controllerInputMessage.inputElementType==uKey && controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){
            
            
            return true;
            
        }
        
        return false;
        
    }

    bool U4DGameLogic::isGamePadThumbstickMoved(int uKey, void *uData){
        
        CONTROLLERMESSAGE controllerInputMessage=*(CONTROLLERMESSAGE*)uData;
        
        if(controllerInputMessage.inputElementType==uKey && controllerInputMessage.inputElementAction==U4DEngine::padThumbstickMoved){
            
            
            return true;
            
        }
        
        return false;
        
    }

    bool U4DGameLogic::isGamePadThumbstickReleased(int uKey, void *uData){
     
        CONTROLLERMESSAGE controllerInputMessage=*(CONTROLLERMESSAGE*)uData;
        
        if(controllerInputMessage.inputElementType==uKey && controllerInputMessage.inputElementAction==U4DEngine::padThumbstickReleased){
            
            
            return true;
            
        }
        
        return false;
    }
    
}
