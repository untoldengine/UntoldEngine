//
//  U11AttackSystem.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/3/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11AttackSystem_hpp
#define U11AttackSystem_hpp

#include <stdio.h>
#include "U11AttackSystemInterface.h"
#include "U4DCallback.h"
#include "U4DTimer.h"

class U11Team;

class U11AttackSystem:public U11AttackSystemInterface {

protected:
    
    U11Team *team;
    
    U4DEngine::U4DTimer *supportAnalysisTimer;
    
    U4DEngine::U4DCallback<U11AttackSystem> *scheduler;
    
public:
    
    U11AttackSystem();
    
    ~U11AttackSystem();
    
    void setTeam(U11Team *uTeam);
    
    virtual void analyzePlay(){};
    
    void assignSupportPlayer();
    
    void computeSupportSpace();
    
    void startComputeSupportSpaceTimer();
    
    void removeComputeSupportSpaceTimer();

    
};

#endif /* U11AttackSystem_hpp */
