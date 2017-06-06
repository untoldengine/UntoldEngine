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

U11AISystem::U11AISystem(U11Team *uTeam, U11DefenseSystemInterface *uDefenseSystem, U11AttackSystemInterface *uAttackSystem, U11RecoverSystemInterface *uRecoverSystem){
    
    team=uTeam;
    stateManager=new U11AIStateManager(this);
    
    attackSystem=uAttackSystem;
    defenseSystem=uDefenseSystem;
    recoverSystem=uRecoverSystem;
    
    attackSystem->setTeam(team);
    defenseSystem->setTeam(team);
    
    recoverSystem->setTeam(team);
    
}

U11AISystem::~U11AISystem(){
    
    delete defenseSystem;
    delete attackSystem;
    delete recoverSystem;
    
}

void U11AISystem::setAttackAISystem(U11AttackSystemInterface *uAttackSystem){
    
}

void U11AISystem::setDefendAISystem(U11DefenseSystemInterface *uDefenseSystem){
    
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

U11AttackSystemInterface *U11AISystem::getAttackAISystem(){
    
    return attackSystem;
}

U11DefenseSystemInterface *U11AISystem::getDefenseAISystem(){
    
    return defenseSystem;
}

U11RecoverSystemInterface *U11AISystem::getRecoverAISystem(){
    
    return recoverSystem;
}
