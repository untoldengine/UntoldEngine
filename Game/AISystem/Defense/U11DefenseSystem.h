//
//  U11DefenseSystem.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/3/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11DefenseSystem_hpp
#define U11DefenseSystem_hpp

#include <stdio.h>
#include "U11DefenseSystemInterface.h"
#include "U4DCallback.h"
#include "U4DTimer.h"

class U11Team;

class U11DefenseSystem:public U11DefenseSystemInterface {
    
protected:
    
    U11Team *team;
    
    U4DEngine::U4DTimer *defendAnalysisTimer;
    
    U4DEngine::U4DCallback<U11DefenseSystem> *scheduler;
    
public:
    
    U11DefenseSystem();
    
    ~U11DefenseSystem();
    
    virtual void assignDefendingPlayer(){};
    
    void setTeam(U11Team *uTeam);
    
    void assignDefendingSupportPlayers();
    
    void computeDefendingSpace();
    
    virtual void interceptPass();
    
    void startComputeDefendingSpaceTimer();
    
    void removeComputeDefendingSpaceTimer();
    
    
};

#endif /* U11DefenseSystem_hpp */
