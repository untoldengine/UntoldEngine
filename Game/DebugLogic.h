//
//  DebugLogic.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/13/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef DebugLogic_hpp
#define DebugLogic_hpp

#include <stdio.h>
#include "U4DGameModel.h"
#include "Player.h"
#include "U4DShaderEntity.h"

class Team;

class DebugLogic:public U4DEngine::U4DGameModel{
    
private:
    
    //player
    Player *pPlayer;

    //controlling team
    Team *controllingTeam;
    
    U4DEngine::U4DGameObject *pGround;
    
    bool stickActive;
    
    U4DEngine::U4DVector3n stickDirection;
    
    U4DEngine::U4DShaderEntity *pPlayerIndicator;
    
    MouseMovementDirection mouseMovementDirection;
    
    U4DEngine::U4DVector2n currentMousePosition;
    
    bool showDirectionLine;
    
public:
    
    DebugLogic();
    
    ~DebugLogic();
    
    void update(double dt);
    
    void init();
    
    void receiveUserInputUpdate(void *uData);
    
    void setControllingTeam(Team *uTeam);
    
    void setPlayerIndicator(U4DEngine::U4DShaderEntity *uPlayerIndicator);
    
};
#endif /* DebugLogic_hpp */
