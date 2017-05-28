//
//  AISystem.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/21/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11AISystem.h"
#include "U11AIAnalyzer.h"
#include "U11AIStateManager.h"
#include "U11AttackAISystem.h"
#include "U11DefenseAISystem.h"

U11AISystem::U11AISystem(U11Team *uTeam){
    
    team=uTeam;
    stateManager=new U11AIStateManager(this);
    attackAISystem.setTeam(team);
    defenseAISystem.setTeam(team);
    recoverAISystem.setTeam(team);
    
}

U11AISystem::~U11AISystem(){
    
}

void U11AISystem::setAttackAIStrategy(){
    
}

void U11AISystem::setDefendAIStrategy(){
    
}

void U11AISystem::changeState(U11AIStateInterface* uState){
    
    stateManager->changeState(uState);
    
}

U11Team *U11AISystem::getTeam(){
    
    return team;
}

U11AIStateManager *U11AISystem::getStateManager(){
    
    return stateManager;
}

U11AttackAISystem &U11AISystem::getAttackAISystem(){
    
    return attackAISystem;
}

U11DefenseAISystem &U11AISystem::getDefenseAISystem(){
    
    return defenseAISystem;
}

U11RecoverAISystem &U11AISystem::getRecoverAISystem(){
    
    return recoverAISystem;
}
