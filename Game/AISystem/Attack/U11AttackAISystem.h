//
//  AIAttackSystem.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/21/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef AIAttackSystem_hpp
#define AIAttackSystem_hpp

#include <stdio.h>
#include "U4DCallback.h"
#include "U4DTimer.h"

class U11Team;

class U11AttackAISystem {
    
private:
    
    U11Team *team;
    
    U4DEngine::U4DTimer *supportAnalysisTimer;
    
    U4DEngine::U4DCallback<U11AttackAISystem> *scheduler;
    
public:
    
    U11AttackAISystem();
    
    ~U11AttackAISystem();
    
    void setTeam(U11Team *uTeam);
        
    void assignSupportPlayer();
    
    void computeSupportSpace();
    
    void startComputeSupportSpaceTimer();
    
    void removeComputeSupportSpaceTimer();

    
    
};
#endif /* AIAttackSystem_hpp */
