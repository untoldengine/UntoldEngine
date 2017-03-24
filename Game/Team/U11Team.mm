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

U11Team::U11Team():controllingPlayer(NULL),supportPlayer(NULL){
    
}

U11Team::~U11Team(){
    
}

void U11Team::subscribe(U11Player* uPlayer){
    
    teammates.push_back(uPlayer);
}

void U11Team::remove(U11Player* uPlayer){
    
//    //get the player's name
//    std::string name=uPlayer->getName();
//    
//    //remove player from the container
//    players.erase(std::remove_if(players.begin(), players.end(), [&](U11Player* player){return player->getName().compare(name)==0;}),players.end());
//    
}


std::vector<U11Player*> U11Team::getTeammates(){
    return teammates;
}

U11Team *U11Team::getOppositeTeam(){
    
    return oppositeTeam;
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

U11Player* U11Team::getSupportPlayer(){
    
    return supportPlayer;
    
}

void U11Team::setSupportPlayer(U11Player* uPlayer){
    
    supportPlayer=uPlayer;
    
}

std::vector<U11Player*> U11Team::sortPlayersDistanceToPosition(U4DEngine::U4DVector3n &uPosition){
    
    //get each support player into a node with its distance to uPosition
    
    uPosition.y=0;
    
    //set up the heapsort container
    std::vector<U11Node> heapContainer;
    
    for(auto n:teammates){
        
        if (n!=n->getTeam()->getControllingPlayer()) {
            
            U4DEngine::U4DVector3n playerPosition=n->getAbsolutePosition();
            playerPosition.y=0;
            
            float distance=(uPosition-playerPosition).magnitude();
            
            //create a node
            U11Node node;
            node.player=n;
            node.data=distance;
            
            heapContainer.push_back(node);
            
        }
        
    }
    
    //sort the players closer to the position
    
    U11HeapSort heapSort;
    heapSort.heapify(heapContainer);
    
    std::vector<U11Player*> sortPlayers;
    
    for(auto n:heapContainer){
        
        sortPlayers.push_back(n.player);
    }
    
    return sortPlayers;
}

std::vector<U11Player*> U11Team::analyzeClosestPlayersToBall(){
    
    //get position of the ball
    U4DEngine::U4DVector3n ballPosition=soccerBall->getAbsolutePosition();
    
    return sortPlayersDistanceToPosition(ballPosition);
    
}

std::vector<U11Player*> U11Team::analyzeClosestPlayersToPosition(U4DEngine::U4DVector3n &uPosition){
    
    
    return sortPlayersDistanceToPosition(uPosition);
    
}

std::vector<U11Player*> U11Team::analyzeClosestPlayersAlongLine(U4DEngine::U4DSegment &uLine){
    
    //get each support player into a node with its distance to uPosition
    
    uLine.pointA.y=0.0;
    uLine.pointB.y=0.0;
    
    //set up the heapsort container
    std::vector<U11Node> heapContainer;
    
    for(auto n:teammates){
        
        if (n!=n->getTeam()->getControllingPlayer()) {
            
            U4DEngine::U4DPoint3n playerPosition=n->getAbsolutePosition().toPoint();
            playerPosition.y=0;
            
            float distance=uLine.sqDistancePointSegment(playerPosition);
            
            //create a node
            U11Node node;
            node.player=n;
            node.data=distance;
            
            heapContainer.push_back(node);
            
        }
        
    }
    
    //sort the players closer to the position
    
    U11HeapSort heapSort;
    
    heapSort.heapify(heapContainer);
    
    std::vector<U11Player*> sortPlayers;
    
    for(auto n:heapContainer){
        
        sortPlayers.push_back(n.player);
    }
    
    return sortPlayers;
    
}

std::vector<U11Player*> U11Team::analyzeClosestPlayersAlongPassLine(){
    
    U4DEngine::U4DSegment passLine;
    passLine.pointA=getSoccerBall()->getAbsolutePosition().toPoint();
    passLine.pointB=getSoccerBall()->getVelocity().toPoint();
   
    return analyzeClosestPlayersAlongLine(passLine);
    
}

std::vector<U11Player*> U11Team::analyzeSupportPlayers(){
    
    U4DEngine::U4DVector3n controllingPlayerPosition=controllingPlayer->getAbsolutePosition();
    
    return sortPlayersDistanceToPosition(controllingPlayerPosition);
    
}

void U11Team::assignSupportPlayer(){
    
    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
    
    //send message to new support player to support
    supportPlayer=analyzeSupportPlayers().at(0);
    
    messageDispatcher->sendMessage(0.0, NULL, supportPlayer, msgSupportPlayer);
}
