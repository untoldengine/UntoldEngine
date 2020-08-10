//
//  LevelOneLogic.h
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
#include "Player.h"

class LevelOneLogic:public U4DEngine::U4DGameModel{
    
private:
    
    //player
    Player *pPlayer;
    
    U4DEngine::U4DGameObject *pGround;
     
    float angleAccumulator;
    
    MouseMovementDirection mouseMovementDirection;
    
    U4DEngine::U4DVector2n currentMousePosition;
    
    bool showDirectionLine;
    
public:
    
    LevelOneLogic();
    
    ~LevelOneLogic();
    
    void update(double dt);
    
    void init();
    
    void receiveUserInputUpdate(void *uData);
    
    void setActivePlayer(Player *uActivePlayer);
    
};
#endif /* defined(__UntoldEngine__GameLogic__) */
