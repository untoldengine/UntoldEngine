//
//  U11RecoverSystem.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/4/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11RecoverSystem_hpp
#define U11RecoverSystem_hpp

#include <stdio.h>
#include "U11RecoverSystemInterface.h"
#include "U4DCallback.h"
#include "U4DTimer.h"

class U11Team;

class U11RecoverSystem:public U11RecoverSystemInterface {

protected:
    U11Team *team;
    
    U4DEngine::U4DTimer *closestPlayerAnalysisTimer;
    
    U4DEngine::U4DCallback<U11RecoverSystem> *scheduler;
    
    
public:
    
    U11RecoverSystem();
    
    ~U11RecoverSystem();
    
    void setTeam(U11Team *uTeam);
    
    virtual void computeClosestPlayerToBall();
    
    void startComputeClosestPlayerTimer();
    
    void removeComputeClosestPlayerTimer();
};

#endif /* U11RecoverSystem_hpp */
