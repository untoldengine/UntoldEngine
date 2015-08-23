//
//  U4DGameModel.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DGameModel.h"

namespace U4DEngine {
    
void U4DGameModel::subscribe(U4DWorld* uGameWorld){
    
    gameWorld=uGameWorld;
}

void U4DGameModel::subscribe(U4DControllerInterface *uGameController){
    
    gameController=uGameController;
}

void U4DGameModel::setGameObjectManager(U4DEntityManager *uGameObjectManager){
    
    gameObjectManager=uGameObjectManager;
}

void U4DGameModel::notify(U4DWorld *uGameWorld){
    
    
}

void U4DGameModel::notify(U4DControllerInterface *uGameController){
    
}

}
