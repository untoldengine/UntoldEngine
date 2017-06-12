//
//  AIAttackSystem.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/21/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11AttackAISystem.h"
#include "U11Team.h"
#include "U11AISystem.h"
#include "U11AIAttackStrategyInterface.h"

U11AttackAISystem::U11AttackAISystem(){
    
}

U11AttackAISystem::~U11AttackAISystem(){
    
}


void U11AttackAISystem::analyzePlay(){
    
    team->getAISystem()->getAttackStrategy()->analyzePlay();
    
}
