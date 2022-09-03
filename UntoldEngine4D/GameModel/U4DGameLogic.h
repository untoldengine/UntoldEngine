//
//  U4DGameLogic.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DGameLogic__
#define __UntoldEngine__U4DGameLogic__

#include <iostream>
#include "U4DGameLogicInterface.h"
#include "CommonProtocols.h"

namespace U4DEngine {
class U4DWorld;
}

namespace U4DEngine {
    
class U4DGameLogic:public U4DGameLogicInterface{
  
private:
    
    U4DWorld *gameWorld;
    U4DControllerInterface *gameController;
    U4DEntityManager *gameEntityManager;

public:
    U4DGameLogic(){};
    
    ~U4DGameLogic(){};
    
    virtual void update(double dt){};
    
    virtual void init(){};
    
    
    void setGameEntityManager(U4DEntityManager *uGameEntityManager);
    
    void setGameWorld(U4DWorld *uGameWorld);
    void setGameController(U4DControllerInterface *uGameController);
    
    U4DWorld* getGameWorld();
    U4DControllerInterface* getGameController();
    U4DEntityManager* getGameEntityManager();
    
    void notify(U4DWorld *uGameWorld);
    void notify(U4DControllerInterface *uGameController);
    
    U4DEntity* searchChild(std::string uName);
    
    virtual void receiveUserInputUpdate(void *uData){};
    
    bool isMouseLeftButtonPressed(void *uData);
    bool isMouseLeftButtonReleased(void *uData);
    
    bool isMouseRightButtonPressed(void *uData);
    bool isMouseRightButtonReleased(void *uData);
    
    bool isKeyPressed(int uKey, void *uData);
    
    bool isKeyReleased(int uKey, void *uData);
    
    bool isMouseActive(void *uData);
    
    bool isMouseActiveDelta(void *uData);
    
    bool isGamePadButtonPressed(int uKey, void *uData);
    
    bool isGamePadButtonReleased(int uKey, void *uData);
    
    bool isGamePadThumbstickMoved(int uKey, void *uData);
    
    bool isGamePadThumbstickReleased(int uKey, void *uData);
    
};
    
}
#endif /* defined(__UntoldEngine__U4DGameLogic__) */
