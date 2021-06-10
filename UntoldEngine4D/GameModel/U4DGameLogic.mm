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
    
}
