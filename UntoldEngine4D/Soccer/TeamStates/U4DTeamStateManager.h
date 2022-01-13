//
//  U4DTeamStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/8/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DTeamStateManager_hpp
#define U4DTeamStateManager_hpp

#include <stdio.h>
#include "U4DTeamStateInterface.h"
#include "CommonProtocols.h"

namespace U4DEngine{

class U4DTeam;

class U4DTeamStateManager{
  
private:
    
    U4DTeam *team;
    
    U4DTeamStateInterface *previousState;
    
    U4DTeamStateInterface *currentState;
    
    U4DTeamStateInterface *nextState;
    
    bool changeStateRequest;
    
public:
    
    U4DTeamStateManager(U4DTeam *uTeam);
    
    ~U4DTeamStateManager();
    
    void changeState(U4DTeamStateInterface *uState);
    
    void update(double dt);
    
    bool isSafeToChangeState();
    
    void safeChangeState(U4DTeamStateInterface *uState);
     
    bool handleMessage(Message &uMsg);
    
    U4DTeamStateInterface *getCurrentState();
    
    U4DTeamStateInterface *getPreviousState();
    
};

}

#endif /* U4DTeamStateManager_hpp */
