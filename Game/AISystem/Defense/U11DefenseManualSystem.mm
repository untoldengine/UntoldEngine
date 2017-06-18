//
//  U11DefenseManualSystem.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/3/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11DefenseManualSystem.h"
#include "U11Team.h"
#include "U11SpaceAnalyzer.h"
#include "U11FormationInterface.h"
#include "U11MessageDispatcher.h"
#include "U11Player.h"

U11DefenseManualSystem::U11DefenseManualSystem(){
    
}

U11DefenseManualSystem::~U11DefenseManualSystem(){
    
}

void U11DefenseManualSystem::assignDefendingPlayer(){
    
    if (team->getManualDefendingPlayer()) {
        
        U11SpaceAnalyzer spaceAnalyzer;
        
        team->setMainDefendingPlayer(spaceAnalyzer.getClosestDefendingPlayers(team).at(0));
        
        //Set the defending position
        
        U11Player *oppositeControllingPlayer=team->getOppositeTeam()->getControllingPlayer();
        
        U4DEngine::U4DPoint3n defendingSpace=spaceAnalyzer.computeMovementRelToFieldGoal(team, oppositeControllingPlayer,defenseSpace);
        
        team->getMainDefendingPlayer()->setDefendingPosition(defendingSpace);
        
        team->setManualDefendingPlayer(false);
    }
    
}


void U11DefenseManualSystem::interceptPass(){
    
}
