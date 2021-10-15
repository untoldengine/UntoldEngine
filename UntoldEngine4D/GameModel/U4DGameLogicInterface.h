//
//  gameLogicInterface.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DGameLogicInterface__
#define __UntoldEngine__U4DGameLogicInterface__

#include <iostream>
#include "CommonProtocols.h"

namespace U4DEngine {
    
class U4DWorld;
class U4DControllerInterface;
class U4DEntityManager;
class U4DEntity;
    
}

namespace U4DEngine {
    
class U4DGameLogicInterface{
    
public:

    U4DGameLogicInterface(){};
    virtual ~U4DGameLogicInterface(){};
    
    virtual void update(double dt)=0;
    virtual void init()=0;
        
    virtual void setGameEntityManager(U4DEntityManager *uGameEntityManager)=0;
    
    virtual void setGameWorld(U4DWorld *uGameWorld)=0;
    virtual void setGameController(U4DControllerInterface *uGameController)=0;
    
    virtual U4DWorld* getGameWorld()=0;
    virtual U4DControllerInterface* getGameController()=0;
    virtual U4DEntityManager* getGameEntityManager()=0;
    
    virtual void notify(U4DWorld *uGameWorld)=0;
    virtual void notify(U4DControllerInterface *uGameController)=0;
    
    virtual U4DEntity* searchChild(std::string uName)=0;
    
    virtual void receiveUserInputUpdate(void *uData)=0;
    
};
    
}

#endif /* defined(__UntoldEngine__U4DGameLogicInterface__) */
