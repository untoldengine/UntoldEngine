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
#include "U11AIAttackStrategyInterface.h"

U11AISystem::U11AISystem(U11Team *uTeam, U11DefenseSystemInterface *uDefenseSystem, U11AttackSystemInterface *uAttackSystem, U11RecoverSystemInterface *uRecoverSystem, U11AIAttackStrategyInterface *uAttackStrategy):ballIsBeingPassed(false){
    
    team=uTeam;
    stateManager=new U11AIStateManager(this);
    
    attackSystem=uAttackSystem;
    defenseSystem=uDefenseSystem;
    recoverSystem=uRecoverSystem;
    
    attackStrategy=uAttackStrategy;
    
    attackSystem->setTeam(team);
    defenseSystem->setTeam(team);
    
    recoverSystem->setTeam(team);
    
    if (attackStrategy!=nullptr) {
        attackStrategy->setTeam(team);
    }
    
}

U11AISystem::~U11AISystem(){
    
    delete defenseSystem;
    delete attackSystem;
    delete recoverSystem;
    
    delete attackStrategy;
    
}


void U11AISystem::changeState(U11AIStateInterface* uState){
    
    stateManager->changeState(uState);
    
}

U11Team *U11AISystem::getTeam(){
    
    return team;
}

void U11AISystem::setBallIsBeingPassed(bool uValue){
    
    ballIsBeingPassed=uValue;
}

bool U11AISystem::getBallIsBeingPassed(){
 
    return ballIsBeingPassed;
    
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

U11AIAttackStrategyInterface *U11AISystem::getAttackStrategy(){
 
    return attackStrategy;
}
