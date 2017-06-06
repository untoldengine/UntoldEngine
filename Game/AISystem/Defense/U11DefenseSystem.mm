//
//  U11DefenseSystem.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/3/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11DefenseSystem.h"
#include "U11Team.h"
#include "U11SpaceAnalyzer.h"
#include "U11FormationInterface.h"
#include "U11MessageDispatcher.h"
#include "U11Player.h"

U11DefenseSystem::U11DefenseSystem(){
    
    scheduler=new U4DEngine::U4DCallback<U11DefenseSystem>;
    defendAnalysisTimer=new U4DEngine::U4DTimer(scheduler);
    
}

U11DefenseSystem::~U11DefenseSystem(){
    
    delete scheduler;
    delete defendAnalysisTimer;
    
}

void U11DefenseSystem::setTeam(U11Team *uTeam){
    
    team=uTeam;
}


void U11DefenseSystem::computeDefendingSpace(){
    
    U11SpaceAnalyzer spaceAnalyzer;
    
    U11Player *oppositeControllingPlayer=team->getOppositeTeam()->getControllingPlayer();
    
    U4DEngine::U4DVector3n defendingSpace=(spaceAnalyzer.computeMovementRelToFieldGoal(team, oppositeControllingPlayer,formationDefenseSpace)).toVector();
    
    team->getTeamFormation()->translateFormation(defendingSpace);
    
    //change the home position for each player
    
    team->updateTeamFormationPosition();
    
    //get defending player closer to ball
    assignDefendingPlayer();
    
    //get the support defending players
    assignDefendingSupportPlayers();
    
    //message all the players to get to their home position
    
    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
    
    U11Player *mainDefendingPlayer=team->getMainDefendingPlayer();
    U11Player *supportDefendingPlayer1=team->getSupportDefendingPlayer1();
    U11Player *supportDefendingPlayer2=team->getSupportDefendingPlayer2();
    
    for(auto n:team->getTeammates()){
        
        if (n!=mainDefendingPlayer && n!=supportDefendingPlayer1 && n!=supportDefendingPlayer2) {
            messageDispatcher->sendMessage(0.0, NULL, n, msgRunToDefendingFormation);
        }
        
    }
    
}

void U11DefenseSystem::assignDefendingSupportPlayers(){
    
    U11SpaceAnalyzer spaceAnalyzer;
    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
    
    //get threatening players
    std::vector<U11Player*> threateningPlayers=spaceAnalyzer.analyzeThreateningPlayers(team);
    
    if (threateningPlayers.size()>2) {
        
        threateningPlayers.resize(2);
        
    }
    
    if (threateningPlayers.size()==1) {
        
        U11Player *defendingPlayer1=spaceAnalyzer.getDefensePlayerClosestToThreatingPlayer(team, threateningPlayers.at(0));
        
        U4DEngine::U4DPoint3n defendingPosition1=spaceAnalyzer.computeMovementRelToFieldGoal(team, threateningPlayers.at(0),defenseSpace);
        
        defendingPlayer1->setDefendingPosition(defendingPosition1);
        
        team->setSupportDefendingPlayer1(defendingPlayer1);
        
        messageDispatcher->sendMessage(0.0, NULL, defendingPlayer1, msgRunToDefend);
        
    }else if (threateningPlayers.size()==2){
        
        U11Player *defendingPlayer1=spaceAnalyzer.getDefensePlayerClosestToThreatingPlayer(team, threateningPlayers.at(0));
        
        U4DEngine::U4DPoint3n defendingPosition1=spaceAnalyzer.computeMovementRelToFieldGoal(team, threateningPlayers.at(0),defenseSpace);
        
        defendingPlayer1->setDefendingPosition(defendingPosition1);
        
        team->setSupportDefendingPlayer1(defendingPlayer1);
        
        messageDispatcher->sendMessage(0.0, NULL, defendingPlayer1, msgRunToDefend);
        
        
        
        U11Player *defendingPlayer2=spaceAnalyzer.getDefensePlayerClosestToThreatingPlayer(team, threateningPlayers.at(1));
        
        U4DEngine::U4DPoint3n defendingPosition2=spaceAnalyzer.computeMovementRelToFieldGoal(team, threateningPlayers.at(1),defenseSpace);
        
        
        defendingPlayer2->setDefendingPosition(defendingPosition2);
        
        team->setSupportDefendingPlayer2(defendingPlayer2);
        
        messageDispatcher->sendMessage(0.0, NULL, defendingPlayer2, msgRunToDefend);
    }
    
}

void U11DefenseSystem::interceptPass(){
    
    
    U11SpaceAnalyzer spaceAnalyzer;
    
    //1. get the ball future position
    //get controlling player position
    
    U11Player *oppositeControllingPlayer=team->getOppositeTeam()->getControllingPlayer();
    
    U4DEngine::U4DPoint3n pointA=oppositeControllingPlayer->getAbsolutePosition().toPoint();
    
    //get ball heading
    U4DEngine::U4DVector3n ballVelocity=team->getSoccerBall()->getVelocity();
    
    ballVelocity.normalize();
    
    U4DEngine::U4DPoint3n ballDirection=ballVelocity.toPoint();
    
    //get ball kick speed
    float t=oppositeControllingPlayer->getBallKickSpeed();
    
    //get the destination point
    U4DEngine::U4DVector3n pointB=(pointA+ballDirection*t).toVector();
    
    //2. get closest player to end point
    U11Player* interceptPlayer=spaceAnalyzer.analyzeClosestPlayersToPosition(pointB,team).at(0);
    
    //3. if the player is closed enough to intercept, then send message to intercept pass
    
    U4DEngine::U4DVector3n playerPosition=interceptPlayer->getAbsolutePosition();
    
    if ((playerPosition-pointB).magnitude()<minimumInterceptionDistance) {
        
        U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
        
        messageDispatcher->sendMessage(0.0, NULL, interceptPlayer, msgIntercept);
        
    }
    
}

void U11DefenseSystem::startComputeDefendingSpaceTimer(){
    
    scheduler->scheduleClassWithMethodAndDelay(this, &U11DefenseSystem::computeDefendingSpace, defendAnalysisTimer, 0.5, true);
    
}

void U11DefenseSystem::removeComputeDefendingSpaceTimer(){
    
    scheduler->unScheduleTimer(defendAnalysisTimer);
    
}
