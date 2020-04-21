//
//  GameLogic.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__GameLogic__
#define __UntoldEngine__GameLogic__

#include <iostream>
#include "U4DGameModel.h"
#include "UserCommonProtocols.h"
#include "U4DGameObject.h"

class GameLogic:public U4DEngine::U4DGameModel{
    
private:
    
    //astronaut
    U4DEngine::U4DGameObject *pAstronaut;
     
    float angleAccumulator;
    
    MouseMovementDirection mouseMovementDirection;
    
public:
    
    GameLogic();
    
    ~GameLogic();
    
    void update(double dt);
    
    void init();
    
    void receiveUserInputUpdate(void *uData);
    
};
#endif /* defined(__UntoldEngine__GameLogic__) */
