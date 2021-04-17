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
#include "Player.h"
#include "U4DShaderEntity.h"

class Team;

class LevelOneLogic:public U4DEngine::U4DGameModel{
    
private:
    
    //player
    Player *pPlayer;

    //controlling team
    Team *controllingTeam;
    
    //marking team
    Team *markingTeam;
    
    U4DEngine::U4DGameObject *pGround;
    
    bool stickActive;
    
    U4DEngine::U4DVector3n stickDirection;
    
    U4DEngine::U4DShaderEntity *pPlayerIndicator;
    
    MouseMovementDirection mouseMovementDirection;
    
    U4DEngine::U4DVector2n currentMousePosition;
    
    bool showDirectionLine;
    
public:
    
    LevelOneLogic();
    
    ~LevelOneLogic();
    
    void update(double dt);
    
    void init();
    
    void receiveUserInputUpdate(void *uData);
    
    void setControllingTeam(Team *uTeam);
    
    void setMarkingTeam(Team *uTeam);
    
    void setPlayerIndicator(U4DEngine::U4DShaderEntity *uPlayerIndicator);
    
};
#endif /* defined(__UntoldEngine__GameLogic__) */
