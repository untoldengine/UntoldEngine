//
//  U11Team.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/4/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11Team.h"
#include <string>

U11Team::U11Team():controllingPlayer(NULL),receivingPlayer(NULL),playerClosestToBall(NULL),supportingPlayer(NULL){
    
}

U11Team::~U11Team(){
    
}

void U11Team::subscribe(U11Player* uPlayer){
    
    players.push_back(uPlayer);
}

void U11Team::remove(U11Player* uPlayer){
    
    //get the player's name
    std::string name=uPlayer->getName();
    
    //remove player from the container
    players.erase(std::remove_if(players.begin(), players.end(), [&](U11Player* player){return player->getName().compare(name)==0;}),players.end());
    
}

void U11Team::setControllingPlayer(U11Player *uPlayer){
    
    controllingPlayer=uPlayer;
    
}

void U11Team::setReceivingPlayer(U11Player *uPlayer){
    
    receivingPlayer=uPlayer;
    
}

void U11Team::setSupportingPlayer(U11Player *uPlayer){
    
    supportingPlayer=uPlayer;
    
}

void U11Team::setPlayerClosestToBall(U11Player *uPlayer){
    
    playerClosestToBall=uPlayer;
    
}

U11Player *U11Team::getControllingPlayer(){
    
    return controllingPlayer;
}

U11Player *U11Team::getReceivingPlayer(){
 
    return receivingPlayer;
}

U11Player *U11Team::getSupportingPlayer(){
    
    return supportingPlayer;
}

U11Player *U11Team::getPlayerClosestToBall(){
    
    return playerClosestToBall;
}

std::vector<U11Player*> U11Team::getAllPlayers(){
    
}
