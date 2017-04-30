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
#include "UserCommonProtocols.h"
#include "U11FormationInterface.h"
#include "U11FormationEntity.h"
#include "U11Player.h"
#include "UserCommonProtocols.h"


U11Team::U11Team(U11FormationInterface *uTeamFormation, U4DEngine::U4DWorld *uWorld, int uFieldQuadrant):controllingPlayer(NULL),supportPlayer1(NULL),supportPlayer2(NULL){
    
    stateManager=new U11TeamStateManager(this);
    scheduler=new U4DEngine::U4DCallback<U11Team>;
    supportAnalysisTimer=new U4DEngine::U4DTimer(scheduler);
    defendAnalysisTimer=new U4DEngine::U4DTimer(scheduler);
    
    fieldQuadrant=uFieldQuadrant;
    
    teamFormation=uTeamFormation;
    
    teamFormation->init(uWorld, fieldQuadrant);
    
}

U11Team::~U11Team(){
    
    delete scheduler;
    delete supportAnalysisTimer;
    delete defendAnalysisTimer;
    
}

void U11Team::subscribe(U11Player* uPlayer){
    
    teammates.push_back(uPlayer);
    
    uPlayer->setFormationEntity(teamFormation->assignFormationEntity());
    
}

void U11Team::remove(U11Player* uPlayer){
    
    //get the player's name
    std::string name=uPlayer->getName();
    
    //unassign the formation entity
    uPlayer->getFormationEntity()->setAssigned(false);
    
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

void U11Team::setMainDefendingPlayer(U11Player *uPlayer){
    
    mainDefendingPlayer=uPlayer;
}

U11Player *U11Team::getMainDefendingPlayer(){
    
    return mainDefendingPlayer;
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

std::vector<U11Player*> U11Team::analyzeDefendingPlayer(){
    
    U11Player *oppositeControllingPlayer=getOppositeTeam()->getControllingPlayer();
    U4DEngine::U4DVector3n oppositePlayerPosition=oppositeControllingPlayer->getAbsolutePosition();
    
    U11SpaceAnalyzer spaceAnalyzer;
    
    return spaceAnalyzer.analyzePlayersDistanceToPosition(this, oppositePlayerPosition);
    
}

void U11Team::assignSupportPlayer(){
    
    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
    
    //send message to new support player to support
    supportPlayer1=analyzeSupportPlayers().at(0);
    
    messageDispatcher->sendMessage(0.0, NULL, supportPlayer1, msgSupportPlayer);
    
    supportPlayer2=analyzeSupportPlayers().at(1);
    
    messageDispatcher->sendMessage(0.0, NULL, supportPlayer2, msgSupportPlayer);

}

void U11Team::assignDefendingPlayer(){
    
    U11SpaceAnalyzer spaceAnalyzer;
    
    mainDefendingPlayer=analyzeDefendingPlayer().at(0);
    
    //Set the defending position
    
    U11Player *oppositeControllingPlayer=getOppositeTeam()->getControllingPlayer();
    
    U4DEngine::U4DPoint3n defendingSpace=spaceAnalyzer.computeMovementRelToFieldGoal(this, oppositeControllingPlayer,defenseSpace);
    
    mainDefendingPlayer->setDefendingPosition(defendingSpace);
    
    //send message to defending player
    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
    
    messageDispatcher->sendMessage(0.0, NULL, mainDefendingPlayer, msgRunToSteal);
    
}


void U11Team::computeSupportSpace(){

    U11SpaceAnalyzer spaceAnalyzer;
    
    //translate the formation
    U11Player *controllingPlayer=getControllingPlayer();
    
    U4DEngine::U4DVector3n formationSupportSpace=(spaceAnalyzer.computeMovementRelToFieldGoal(this, controllingPlayer,formationDefenseSpace)).toVector();
    
    teamFormation->translateFormation(formationSupportSpace);
    
    //change the home position for each player
    
    updateTeamFormationPosition();
    
    //assign the support players
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
    
    //message all the players to get to their home position
    
    for(auto n:teammates){
        
        if (n!=controllingPlayer && n!=supportPlayer1 && n!=supportPlayer2) {
            messageDispatcher->sendMessage(0.0, NULL, n, msgRunToAttackFormation);
        }
        
    }
    
}

void U11Team::computeDefendingSpace(){
    
    U11SpaceAnalyzer spaceAnalyzer;
    
    U11Player *oppositeControllingPlayer=getOppositeTeam()->getControllingPlayer();
    
    U4DEngine::U4DVector3n defendingSpace=(spaceAnalyzer.computeMovementRelToFieldGoal(this, oppositeControllingPlayer,formationDefenseSpace)).toVector();
    
    teamFormation->translateFormation(defendingSpace);
    
    //change the home position for each player
    
    updateTeamFormationPosition();
    
    //get defending player closer to ball
    assignDefendingPlayer();
    
    //get the support defending players
    assignDefendingSupportPlayers();
    
    //message all the players to get to their home position
    
    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
    
    for(auto n:teammates){
        
        if (n!=mainDefendingPlayer && n!=supportDefendingPlayer1 && n!=supportDefendingPlayer2) {
            messageDispatcher->sendMessage(0.0, NULL, n, msgRunToDefendingFormation);
        }
        
    }

}

void U11Team::startComputeSupportSpaceTimer(){
    
    scheduler->scheduleClassWithMethodAndDelay(this, &U11Team::computeSupportSpace, supportAnalysisTimer, 0.8, true);
    
}

void U11Team::removeComputeSupportStateTimer(){
    
    scheduler->unScheduleTimer(supportAnalysisTimer);
    
}

void U11Team::startComputeDefendingSpaceTimer(){
    
    scheduler->scheduleClassWithMethodAndDelay(this, &U11Team::computeDefendingSpace, defendAnalysisTimer, 0.8, true);
    
}

void U11Team::removeComputeDefendingStateTimer(){
    
    scheduler->unScheduleTimer(defendAnalysisTimer);
    
}

void U11Team::translateTeamToFormationPosition(){
    
    for(auto n:teammates){
        
        U4DEngine::U4DVector3n pos=n->getFormationEntity()->getAbsolutePosition();
        pos.y=n->getModelDimensions().y/2.0+1.3;
        
        U4DEngine::U4DPoint3n formationPosition=pos.toPoint();
        
        n->setFormationPosition(formationPosition);
        
        n->translateTo(pos);
        
    }
}

void U11Team::updateTeamFormationPosition(){
    
    for(auto n:teammates){
        
        U4DEngine::U4DPoint3n pos=(n->getFormationEntity()->getAbsolutePosition()).toPoint();
        pos.y=n->getModelDimensions().y/2.0+1.3;
        
        n->setFormationPosition(pos);
    
    }
    
}

void U11Team::assignDefendingSupportPlayers(){
    
    U11SpaceAnalyzer spaceAnalyzer;
    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
    
    //get threatening players
    std::vector<U11Player*> threateningPlayers=spaceAnalyzer.analyzeThreateningPlayers(this);
    
    if (threateningPlayers.size()>2) {
        
        threateningPlayers.resize(2);
        
    }
    
    if (threateningPlayers.size()==1) {
        
        U11Player *defendingPlayer1=spaceAnalyzer.getDefensePlayerClosestToThreatingPlayer(this, threateningPlayers.at(0));
        
        U4DEngine::U4DPoint3n defendingPosition1=spaceAnalyzer.computeMovementRelToFieldGoal(this, threateningPlayers.at(0),defenseSpace);
        
        defendingPlayer1->setDefendingPosition(defendingPosition1);
        
        setSupportDefendingPlayer1(defendingPlayer1);
        
        messageDispatcher->sendMessage(0.0, NULL, defendingPlayer1, msgRunToDefend);
        
    }else if (threateningPlayers.size()==2){
        
        U11Player *defendingPlayer1=spaceAnalyzer.getDefensePlayerClosestToThreatingPlayer(this, threateningPlayers.at(0));
        
        U4DEngine::U4DPoint3n defendingPosition1=spaceAnalyzer.computeMovementRelToFieldGoal(this, threateningPlayers.at(0),defenseSpace);
        
        defendingPlayer1->setDefendingPosition(defendingPosition1);
        
        setSupportDefendingPlayer1(defendingPlayer1);
        
        messageDispatcher->sendMessage(0.0, NULL, defendingPlayer1, msgRunToDefend);
        
        
        
        U11Player *defendingPlayer2=spaceAnalyzer.getDefensePlayerClosestToThreatingPlayer(this, threateningPlayers.at(1));
        
        U4DEngine::U4DPoint3n defendingPosition2=spaceAnalyzer.computeMovementRelToFieldGoal(this, threateningPlayers.at(1),defenseSpace);
        
        
        defendingPlayer2->setDefendingPosition(defendingPosition2);
        
        setSupportDefendingPlayer2(defendingPlayer2);
        
        messageDispatcher->sendMessage(0.0, NULL, defendingPlayer2, msgRunToDefend);
    }
    
}

void U11Team::setSupportDefendingPlayer1(U11Player *uPlayer){
    
    supportDefendingPlayer1=uPlayer;
}

U11Player *U11Team::getSupportDefendingPlayer1(){
    
    return supportDefendingPlayer1;
}

void U11Team::setSupportDefendingPlayer2(U11Player *uPlayer){
    
    supportDefendingPlayer2=uPlayer;
    
}

U11Player *U11Team::getSupportDefendingPlayer2(){
 
    return supportDefendingPlayer2;
}


