//
//  GuardianRunState.h
//  UntoldEngine
//
//  Created by Harold Serrano on 11/6/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef GuardianRunState_h
#define GuardianRunState_h

#include <stdio.h>
#include "GuardianStateInterface.h"
#include "UserCommonProtocols.h"

class GuardianRunState:public GuardianStateInterface {
    
private:
    
    GuardianRunState();
    
    ~GuardianRunState();
    
public:
    
    static GuardianRunState* instance;
    
    static GuardianRunState* sharedInstance();
    
    void enter(GuardianModel *uGuardian);
    
    void execute(GuardianModel *uGuardian, double dt);
    
    void exit(GuardianModel *uGuardian);
    
    bool isSafeToChangeState(GuardianModel *uGuardian);
    
    bool handleMessage(GuardianModel *uGuardian, Message &uMsg);
    
};
#endif /* GuardianRunState_h */
