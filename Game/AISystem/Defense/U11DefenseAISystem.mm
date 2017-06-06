//
//  AIDefenseSystem.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/21/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11DefenseAISystem.h"
#include "U11Team.h"
#include "U11SpaceAnalyzer.h"
#include "U11FormationInterface.h"
#include "U11MessageDispatcher.h"
#include "U11Player.h"

U11DefenseAISystem::U11DefenseAISystem(){
    
     
}

U11DefenseAISystem::~U11DefenseAISystem(){
    
}


void U11DefenseAISystem::assignDefendingPlayer(){
    
    U11SpaceAnalyzer spaceAnalyzer;
    
    team->setMainDefendingPlayer(spaceAnalyzer.analyzeDefendingPlayer(team).at(0));
    
    //Set the defending position
    
    U11Player *oppositeControllingPlayer=team->getOppositeTeam()->getControllingPlayer();
    
    U4DEngine::U4DPoint3n defendingSpace=spaceAnalyzer.computeMovementRelToFieldGoal(team, oppositeControllingPlayer,defenseSpace);
    
    team->getMainDefendingPlayer()->setDefendingPosition(defendingSpace);
    
    //send message to defending player
    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
    
    messageDispatcher->sendMessage(0.0, NULL, team->getMainDefendingPlayer(), msgRunToSteal);
    
}

