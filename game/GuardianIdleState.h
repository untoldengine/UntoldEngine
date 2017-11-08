//
//  GuardianIdleState.h
//  UntoldEngine
//
//  Created by Harold Serrano on 11/6/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef GuardianIdleState_h
#define GuardianIdleState_h

#include <stdio.h>
#include "GuardianStateInterface.h"
#include "UserCommonProtocols.h"

class GuardianIdleState:public GuardianStateInterface {
    
private:
    
    GuardianIdleState();
    
    ~GuardianIdleState();
    
public:
    
    static GuardianIdleState* instance;
    
    static GuardianIdleState* sharedInstance();
    
    void enter(GuardianModel *uGuardian);
    
    void execute(GuardianModel *uGuardian, double dt);
    
    void exit(GuardianModel *uGuardian);
    
    bool isSafeToChangeState(GuardianModel *uGuardian);
    
    bool handleMessage(GuardianModel *uGuardian, Message &uMsg);
    
};

#endif /* GuardianIdleState_h */
