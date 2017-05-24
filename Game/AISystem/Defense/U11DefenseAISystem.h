//
//  AIDefenseSystem.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/21/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef AIDefenseSystem_hpp
#define AIDefenseSystem_hpp

#include <stdio.h>
#include "U4DCallback.h"
#include "U4DTimer.h"

class U11Team;

class U11DefenseAISystem {
    
private:
    
    U11Team *team;
    
    U4DEngine::U4DTimer *defendAnalysisTimer;
    
    U4DEngine::U4DCallback<U11DefenseAISystem> *scheduler;
    
public:
    
    U11DefenseAISystem();
    
    ~U11DefenseAISystem();
    
    void setTeam(U11Team *uTeam);
    
    void assignDefendingPlayer();
    
    void assignDefendingSupportPlayers();
    
    void computeDefendingSpace();
    
    void startComputeDefendingSpaceTimer();
    
    void removeComputeDefendingSpaceTimer();
    
    void interceptPass();
    
};

#endif /* AIDefenseSystem_hpp */
