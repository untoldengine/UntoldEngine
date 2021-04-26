//
//  TeamStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/21/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef TeamStateManager_hpp
#define TeamStateManager_hpp

#include <stdio.h>
#include "TeamStateInterface.h"
#include "UserCommonProtocols.h"

class Team;

class TeamStateManager{
  
private:
    
    Team *team;
    
    TeamStateInterface *previousState;
    
    TeamStateInterface *currentState;
    
    TeamStateInterface *nextState;
    
    bool changeStateRequest;
    
public:
    
    TeamStateManager(Team *uTeam);
    
    ~TeamStateManager();
    
    void changeState(TeamStateInterface *uState);
    
    void update(double dt);
    
    bool isSafeToChangeState();
    
    void safeChangeState(TeamStateInterface *uState);
    
    bool handleMessage(Message &uMsg);
    
    TeamStateInterface *getCurrentState();
    
    TeamStateInterface *getPreviousState();
    
};
#endif /* TeamStateManager_hpp */
