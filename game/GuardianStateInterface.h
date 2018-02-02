//
//  GuardianStateInterface.h
//  UntoldEngine
//
//  Created by Harold Serrano on 11/6/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef GuardianStateInterface_h
#define GuardianStateInterface_h

#include <stdio.h>
#include "UserCommonProtocols.h"
#include "GuardianModel.h"

class GuardianStateInterface {
    
    
public:
    virtual ~GuardianStateInterface(){};
    
    virtual void enter(GuardianModel *uGuardian)=0;
    
    virtual void execute(GuardianModel *uGuardian, double dt)=0;
    
    virtual void exit(GuardianModel *uGuardian)=0;
    
    virtual bool handleMessage(GuardianModel *uGuardian, Message &uMsg)=0;
    
    virtual bool isSafeToChangeState(GuardianModel *uGuardian)=0;
    
};
#endif /* GuardianStateInterface_h */
