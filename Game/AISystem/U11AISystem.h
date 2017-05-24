//
//  AISystem.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/21/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef AISystem_hpp
#define AISystem_hpp

#include <stdio.h>
#include "U11AttackAISystem.h"
#include "U11DefenseAISystem.h"
#include "U11AIAnalyzer.h"

class U11Team;
class U11AIStateManager;
class U11AIStateInterface;

class U11AISystem {
    
private:
    
    U11AttackAISystem attackAISystem;
    U11DefenseAISystem defenseAISystem;
    U11AIStateManager *stateManager;
    U11Team *team;
    
public:
    
    U11AISystem(U11Team *uTeam);
    
    ~U11AISystem();
    
    void setAttackAIStrategy();
    
    void setDefendAIStrategy();
    
    U11Team *getTeam();
    
    U11AIStateManager *getStateManager();
    
    void changeState(U11AIStateInterface* uState);
    
    U11AttackAISystem &getAttackAISystem();
    
    U11DefenseAISystem &getDefenseAISystem();

    
};

#endif /* AISystem_hpp */
