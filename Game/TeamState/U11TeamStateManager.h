//
//  U11TeamStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/4/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11TeamStateManager_hpp
#define U11TeamStateManager_hpp

#include <stdio.h>

#include "U11TeamStateInterface.h"
#include "UserCommonProtocols.h"

class U11Team;

class U11TeamStateManager {
    
private:
    
    U11Team *team;
    
    U11TeamStateInterface *previousState;
    
    U11TeamStateInterface *currentState;
    
    U11TeamStateInterface *nextState;
    
public:
    
    U11TeamStateManager(U11Team *uTeam);
    
    ~U11TeamStateManager();
    
    void changeState(U11TeamStateInterface *uState);
    
    void update(double dt);
    
    bool handleMessage(Message &uMsg);
    
    U11TeamStateInterface *getCurrentState();
    
};

#endif /* U11TeamStateManager_hpp */
