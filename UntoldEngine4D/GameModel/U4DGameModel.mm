//
//  U4DGameModel.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DGameModel.h"
#include "U4DEntity.h"
#include "U4DEntityManager.h"

namespace U4DEngine {
    
    void U4DGameModel::subscribe(U4DWorld* uGameWorld){
        
        gameWorld=uGameWorld;
    }

    void U4DGameModel::subscribe(U4DControllerInterface *uGameController){
        
        gameController=uGameController;
    }

    void U4DGameModel::setGameEntityManager(U4DEntityManager *uGameEntityManager){
        
        gameEntityManager=uGameEntityManager;
    }

    void U4DGameModel::notify(U4DWorld *uGameWorld){
        
        
    }

    void U4DGameModel::notify(U4DControllerInterface *uGameController){
        
    }

    void U4DGameModel::setGameWorld(U4DWorld *uGameWorld){
        gameWorld=uGameWorld;
    }
    
    U4DEntity* U4DGameModel::searchChild(std::string uName){
        
        return gameEntityManager->searchChild(uName);
    }
}
