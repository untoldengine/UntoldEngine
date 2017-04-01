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

U11Team::U11Team():controllingPlayer(NULL),supportPlayer1(NULL),supportPlayer2(NULL){
    
    
}

U11Team::~U11Team(){
    
    
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

U11Ball *U11Team::getSoccerBall(){
    
    return soccerBall;
    
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
    passLine.pointB=getSoccerBall()->getVelocity().toPoint();
   
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
    
    if (analyzeSupportPlayers().size()>1) {
        
        supportPlayer2=analyzeSupportPlayers().at(1);
        
        messageDispatcher->sendMessage(0.0, NULL, supportPlayer2, msgSupportPlayer);
    }
    
    
}

void U11Team::computeSupportSpace(){
    
    U11SpaceAnalyzer spaceAnalyzer;
    
    std::vector<U4DEngine::U4DPoint3n> supportSpace=spaceAnalyzer.computeOptimalSupportSpace(this);
    
    U4DEngine::U4DPoint3n supportSpace1=supportSpace.at(0);
    U4DEngine::U4DPoint3n supportSpace2=supportSpace.at(1);

    supportPlayer1->setSupportPosition(supportSpace1);
    
    if (supportSpace.size()>1) {
        
        supportPlayer2->setSupportPosition(supportSpace2);
    }
}
