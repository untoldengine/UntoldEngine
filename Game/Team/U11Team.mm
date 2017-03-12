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
#include <string>
#include "U4DNumerical.h"

U11Team::U11Team():controllingPlayer(NULL){
    
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

std::vector<U11Player*> U11Team::sortPlayersDistanceToPosition(U4DEngine::U4DVector3n &uPosition){
    
    U4DEngine::U4DNumerical numerical;
    
    //get each support player into a node with its distance to uPosition
    
    uPosition.y=0;
    
    //set up the heapsort container
    std::vector<U11Node> heapContainer;
    
    for(auto n:teammates){
        
        U4DEngine::U4DVector3n playerPosition=n->getAbsolutePosition();
        playerPosition.y=0;
        
        float distance=(uPosition-playerPosition).magnitude();
        
        if (numerical.areEqual(distance, 0.0, U4DEngine::zeroEpsilon)) {
            
            //ignore if distance is zero. it means it is the same object.
            
        }else{
            
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

std::vector<U11Player*> U11Team::getClosestPlayersToBall(){
    
    //get position of the ball
    U4DEngine::U4DVector3n ballPosition=soccerBall->getAbsolutePosition();
    
    return sortPlayersDistanceToPosition(ballPosition);
    
}

std::vector<U11Player*> U11Team::getSupportPlayers(){
    
    U4DEngine::U4DVector3n controllingPlayerPosition=controllingPlayer->getAbsolutePosition();
    
    return sortPlayersDistanceToPosition(controllingPlayerPosition);
    
}
