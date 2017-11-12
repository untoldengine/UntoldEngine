//
//  GuardianJumpState.h
//  UntoldEngine
//
//  Created by Harold Serrano on 11/6/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef GuardianJumpState_h
#define GuardianJumpState_h

#include <stdio.h>
#include "GuardianStateInterface.h"
#include "UserCommonProtocols.h"

class GuardianJumpState:public GuardianStateInterface {
    
private:
    
    GuardianJumpState();
    
    ~GuardianJumpState();
    
public:
    
    static GuardianJumpState* instance;
    
    static GuardianJumpState* sharedInstance();
    
    void enter(GuardianModel *uGuardian);
    
    void execute(GuardianModel *uGuardian, double dt);
    
    void exit(GuardianModel *uGuardian);
    
    bool isSafeToChangeState(GuardianModel *uGuardian);
    
    bool handleMessage(GuardianModel *uGuardian, Message &uMsg);
    
};

#endif /* GuardianJumpState_h */
