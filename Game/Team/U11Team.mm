//
//  U11Team.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/4/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11Team.h"
#include "U11HeapSort.h"
#include "U4DVector3n.h"
#include "U4DSegment.h"
#include <string>
#include "U4DNumerical.h"
#include "U11MessageDispatcher.h"
#include "U11SpaceAnalyzer.h"
#include "U11TeamStateManager.h"
#include "U11TeamStateInterface.h"

U11Team::U11Team():controllingPlayer(NULL),supportPlayer1(NULL),supportPlayer2(NULL){
    
    stateManager=new U11TeamStateManager(this);
    scheduler=new U4DEngine::U4DCallback<U11Team>;
    supportAnalysisTimer=new U4DEngine::U4DTimer(scheduler);
    defendAnalysisTimer=new U4DEngine::U4DTimer(scheduler);
    
}

U11Team::~U11Team(){
    
    delete scheduler;
    delete supportAnalysisTimer;
    delete defendAnalysisTimer;
    
}

void U11Team::subscribe(U11Player* uPlayer){
    
    teammates.push_back(uPlayer);
}

void U11Team::remove(U11Player* uPlayer){
    
    //get the player's name
    std::string name=uPlayer->getName();
    
    //remove player from the container
    teammates.erase(std::remove_if(teammates.begin(), teammates.end(), [&](U11Player* player){return player->getName().compare(name)==0;}),teammates.end());
    
}

void U11Team::changeState(U11TeamStateInterface* uState){
    
    stateManager->changeState(uState);
}


std::vector<U11Player*> U11Team::getTeammates(){
    return teammates;
}

U11Team *U11Team::getOppositeTeam(){
    
    return oppositeTeam;
}

void U11Team::setOppositeTeam(U11Team *uTeam){
    
    oppositeTeam=uTeam;
}

void U11Team::setSoccerBall(U11Ball *uSoccerBall){
    
    soccerBall=uSoccerBall;
    
}

void U11Team::setFieldGoal(U11FieldGoal *uFieldGoal){
    
    fieldGoal=uFieldGoal;
}

U11Ball *U11Team::getSoccerBall(){
    
    return soccerBall;
    
}

U11FieldGoal *U11Team::getFieldGoal(){
    
    return fieldGoal;
}

U11Player* U11Team::getControllingPlayer(){
    
    return controllingPlayer;
    
}

void U11Team::setControllingPlayer(U11Player* uPlayer){
    
    controllingPlayer=uPlayer;
    
}

U11Player* U11Team::getSupportPlayer1(){
    
    return supportPlayer1;
    
}

void U11Team::setSupportPlayer1(U11Player* uPlayer){
    
    supportPlayer1=uPlayer;
    
}

U11Player* U11Team::getSupportPlayer2(){
    
    return supportPlayer2;
    
}

void U11Team::setSupportPlayer2(U11Player* uPlayer){
    
    supportPlayer2=uPlayer;
    
}

void U11Team::setDefendingPlayer(U11Player *uPlayer){
    
    defendingPlayer=uPlayer;
}

U11Player *U11Team::getDefendingPlayer(){
    
    return defendingPlayer;
}

std::vector<U11Player*> U11Team::analyzeClosestPlayersToBall(){
    
    //get position of the ball
    U4DEngine::U4DVector3n ballPosition=soccerBall->getAbsolutePosition();
    
    U11SpaceAnalyzer spaceAnalyzer;
    
    return spaceAnalyzer.analyzePlayersDistanceToPosition(this, ballPosition);
    
}

std::vector<U11Player*> U11Team::analyzeClosestPlayersToPosition(U4DEngine::U4DVector3n &uPosition){
    
    U11SpaceAnalyzer spaceAnalyzer;
    
    return spaceAnalyzer.analyzePlayersDistanceToPosition(this, uPosition);
    
}

std::vector<U11Player*> U11Team::analyzeClosestPlayersAlongPassLine(){
    
    U4DEngine::U4DSegment passLine;
    passLine.pointA=getSoccerBall()->getAbsolutePosition().toPoint();
    passLine.pointB=getSoccerBall()->getVelocity().toPoint()*ballSegmentDirection;
   
    U11SpaceAnalyzer spaceAnalyzer;
    
    return spaceAnalyzer.analyzeClosestPlayersAlongLine(this,passLine);
    
}

std::vector<U11Player*> U11Team::analyzeSupportPlayers(){
    
    U4DEngine::U4DVector3n controllingPlayerPosition=controllingPlayer->getAbsolutePosition();
    
    U11SpaceAnalyzer spaceAnalyzer;
    
    return spaceAnalyzer.analyzePlayersDistanceToPosition(this, controllingPlayerPosition);
    
}

void U11Team::assignSupportPlayer(){
    
    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
    
    //send message to new support player to support
    supportPlayer1=analyzeSupportPlayers().at(0);
    
    messageDispatcher->sendMessage(0.0, NULL, supportPlayer1, msgSupportPlayer);
    
    supportPlayer2=analyzeSupportPlayers().at(1);
    
    messageDispatcher->sendMessage(0.0, NULL, supportPlayer2, msgSupportPlayer);

}

void U11Team::computeSupportSpace(){

    U11SpaceAnalyzer spaceAnalyzer;
    
    std::vector<U4DEngine::U4DPoint3n> supportSpace=spaceAnalyzer.computeOptimalSupportSpace(this);
    
    U4DEngine::U4DPoint3n supportSpace1=supportSpace.at(0);
    U4DEngine::U4DPoint3n supportSpace2=supportSpace.at(1);

    //compute closest support point to support player
    
    U4DEngine::U4DVector3n supportPlayer1Position=supportPlayer1->getAbsolutePosition();
    U4DEngine::U4DVector3n supportPlayer2Position=supportPlayer2->getAbsolutePosition();
    
    if ((supportPlayer1Position-supportSpace1.toVector()).magnitudeSquare()<(supportPlayer1Position-supportSpace2.toVector()).magnitudeSquare()) {
        
        supportPlayer1->setSupportPosition(supportSpace1);
        supportPlayer2->setSupportPosition(supportSpace2);
        
    }else{
        
        supportPlayer1->setSupportPosition(supportSpace2);
        supportPlayer2->setSupportPosition(supportSpace1);
        
    }

    //send message to player to run to position
    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
    messageDispatcher->sendMessage(0.0, NULL, supportPlayer1, msgRunToSupport);
    messageDispatcher->sendMessage(0.0, NULL, supportPlayer2, msgRunToSupport);
    
}

void U11Team::computeDefendingSpace(){
    
    U11SpaceAnalyzer spaceAnalyzer;
    
    U4DEngine::U4DPoint3n defendingSpace=spaceAnalyzer.computeOptimalDefenseSpace(this);
    
    defendingPlayer->setDefendingPosition(defendingSpace);
    
    //send message to main defender
    
    //prepare message
    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
    
    messageDispatcher->sendMessage(0.0, NULL, defendingPlayer, msgRunToDefend);
    
}

void U11Team::startComputeSupportSpaceTimer(){
    
    scheduler->scheduleClassWithMethodAndDelay(this, &U11Team::computeSupportSpace, supportAnalysisTimer, 2.0, true);
    
}

void U11Team::removeComputeSupportStateTimer(){
    
    scheduler->unScheduleTimer(supportAnalysisTimer);
    
}

void U11Team::startComputeDefendingSpaceTimer(){
    
    scheduler->scheduleClassWithMethodAndDelay(this, &U11Team::computeDefendingSpace, defendAnalysisTimer, 1.0, true);
    
}

void U11Team::removeComputeDefendingStateTimer(){
    
    scheduler->unScheduleTimer(defendAnalysisTimer);
    
}
