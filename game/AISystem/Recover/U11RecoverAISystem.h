//
//  U11RecoverAISystem.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11RecoverAISystem_hpp
#define U11RecoverAISystem_hpp

#include <stdio.h>

#include "U4DCallback.h"
#include "U4DTimer.h"

class U11Team;

class U11RecoverAISystem {
    
private:
    
    U11Team *team;
    
    U4DEngine::U4DTimer *closestPlayerAnalysisTimer;
    
    U4DEngine::U4DCallback<U11RecoverAISystem> *scheduler;
    
public:
    
    U11RecoverAISystem();
    
    ~U11RecoverAISystem();
    
    void setTeam(U11Team *uTeam);
    
    void computeClosestPlayerToBall();
    
    void startComputeClosestPlayerTimer();
    
    void removeComputeClosestPlayerTimer();
    
    
    
};

#endif /* U11TakeControlAISystem_hpp */
