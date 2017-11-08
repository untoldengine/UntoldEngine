//
//  GuardianStateManager.h
//  UntoldEngine
//
//  Created by Harold Serrano on 11/6/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef GuardianStateManager_h
#define GuardianStateManager_h

#include <stdio.h>
#include "GuardianStateInterface.h"
#include "UserCommonProtocols.h"

class GuardianModel;

class GuardianStateManager {
    
private:
    
    GuardianModel *guardian;
    
    GuardianStateInterface *previousState;
    
    GuardianStateInterface *currentState;
    
    GuardianStateInterface *nextState;
    
    bool changeStateRequest;
    
public:
    
    GuardianStateManager(GuardianModel *uGuardian);
    
    ~GuardianStateManager();
    
    void changeState(GuardianStateInterface *uState);
    
    void update(double dt);
    
    bool isSafeToChangeState();
    
    void safeChangeState(GuardianStateInterface *uState);
    
    bool handleMessage(Message &uMsg);
    
    GuardianStateInterface *getCurrentState();
    
};

#endif /* GuardianStateManager_h */
