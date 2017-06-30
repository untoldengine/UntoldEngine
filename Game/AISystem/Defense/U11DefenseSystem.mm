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
//
//    //message all the players to get to their home position
//    
//    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
//    
//    U11Player *mainDefendingPlayer=team->getMainDefendingPlayer();
//    U11Player *supportDefendingPlayer=team->getSupportDefendingPlayer();
//    
//    
//    for(auto n:team->getTeammates()){
//        
//        if (n!=mainDefendingPlayer && n!=supportDefendingPlayer) {
//            messageDispatcher->sendMessage(0.0, NULL, n, msgRunToDefendingFormation);
//        }
//        
//    }
    
}

void U11DefenseSystem::assignDefendingSupportPlayers(){
    
    U11SpaceAnalyzer spaceAnalyzer;
    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
    
    
    //get threatening support players
    U11Player* threateningPlayers=team->getOppositeTeam()->getSupportPlayer();
    
    U11Player *supportDefendingPlayer=spaceAnalyzer.getDefensePlayerClosestToThreatPlayer(team, threateningPlayers);
    
    if (supportDefendingPlayer!=nullptr) {
        
        U4DEngine::U4DPoint3n defendingPosition=spaceAnalyzer.computeMovementRelToFieldGoal(team, threateningPlayers,defenseSpace);
        
        supportDefendingPlayer->setDefendingPosition(defendingPosition);
        
        team->setSupportDefendingPlayer(supportDefendingPlayer);
        
        messageDispatcher->sendMessage(0.0, NULL, supportDefendingPlayer, msgRunToDefend);

    }
    
}

void U11DefenseSystem::interceptPass(){
    
    
//    U11SpaceAnalyzer spaceAnalyzer;
//    
//    //1. get the ball future position
//    //get controlling player position
//    
//    U11Player *oppositeControllingPlayer=team->getOppositeTeam()->getControllingPlayer();
//    
//    U4DEngine::U4DPoint3n pointA=oppositeControllingPlayer->getAbsolutePosition().toPoint();
//    
//    //get ball heading
//    U4DEngine::U4DVector3n ballVelocity=team->getSoccerBall()->getVelocity();
//    
//    ballVelocity.normalize();
//    
//    U4DEngine::U4DPoint3n ballDirection=ballVelocity.toPoint();
//    
//    //get ball kick speed
//    float t=oppositeControllingPlayer->getBallKickSpeed();
//    
//    //get the destination point
//    U4DEngine::U4DVector3n pointB=(pointA+ballDirection*t).toVector();
//    
//    //2. get closest player to end point
//    U11Player* interceptPlayer=spaceAnalyzer.analyzeClosestPlayersToPosition(pointB,team).at(0);
//    
//    //3. if the player is closed enough to intercept, then send message to intercept pass
//    
//    U4DEngine::U4DVector3n playerPosition=interceptPlayer->getAbsolutePosition();
//    
//    if ((playerPosition-pointB).magnitude()<minimumInterceptionDistance) {
//        
//        U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
//        
//        messageDispatcher->sendMessage(0.0, NULL, interceptPlayer, msgIntercept);
//        
//    }
    
}

void U11DefenseSystem::startComputeDefendingSpaceTimer(){
    
    //scheduler->scheduleClassWithMethodAndDelay(this, &U11DefenseSystem::computeDefendingSpace, defendAnalysisTimer, 0.3, true);
    
}

void U11DefenseSystem::removeComputeDefendingSpaceTimer(){
    
    scheduler->unScheduleTimer(defendAnalysisTimer);
    
}
