//
//  PlayerStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/30/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef PlayerStateManager_hpp
#define PlayerStateManager_hpp

#include <stdio.h>
#include "PlayerStateInterface.h"
#include "UserCommonProtocols.h"

class Player;

class PlayerStateManager{
  
private:
    
    Player *player;
    
    PlayerStateInterface *previousState;
    
    PlayerStateInterface *currentState;
    
    PlayerStateInterface *nextState;
    
    bool changeStateRequest;
    
public:
    
    PlayerStateManager(Player *uPlayer);
    
    ~PlayerStateManager();
    
    void changeState(PlayerStateInterface *uState);
    
    void update(double dt);
    
    bool isSafeToChangeState();
    
    void safeChangeState(PlayerStateInterface *uState);
    
    bool handleMessage(Message &uMsg);
    
    PlayerStateInterface *getCurrentState();
    
    PlayerStateInterface *getPreviousState();
    
};

#endif /* PlayerStateManager_hpp */
