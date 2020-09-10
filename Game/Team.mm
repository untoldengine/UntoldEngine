//
//  Team.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/1/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "Team.h"
#include "FieldAnalyzer.h"
#include "PathAnalyzer.h"
#include "Constants.h"

Team::Team():controllingPlayer(nullptr),startingPosition(0.0,0.0,0.0),playerIndex(0){
    
    //Create the callback. Notice that you need to provide the name of the class
    scheduler=new U4DEngine::U4DCallback<Team>;
    
    //create the timer
    timer=new U4DEngine::U4DTimer(scheduler);
    
}

Team::~Team(){
    
    //In the class destructor,  make sure to delete the U4DCallback and U4DTimer as follows.
    //Make sure that before deleting the scheduler and timer, to first unsubscribe the timer.
    
    scheduler->unScheduleTimer(timer);
    delete scheduler;
    delete timer;
    
}

void Team::addPlayer(Player *uPlayer){
    
    uPlayer->addToTeam(this);
    players.push_back(uPlayer);
    
    uPlayer->setPlayerIndex(playerIndex);
    
    playerIndex++;
    
}

std::vector<Player *> Team::getPlayers(){
    
    return players;
    
}

void Team::setOppositeTeam(Team *uTeam){
    
    oppositeTeam=uTeam;
    
}

void Team::startAnalyzing(){
    
    scheduler->scheduleClassWithMethodAndDelay(this, &Team::analyzeField, timer, 3.0,true);
    
}

void Team::analyzeField(){
    
    FieldAnalyzer *fieldAnalyzer=FieldAnalyzer::sharedInstance();
    
    fieldAnalyzer->analyzeField(this,oppositeTeam);
    
//    //get nav path
//    PathAnalyzer *pathAnalyzer=PathAnalyzer::sharedInstance();
//
//    //Get player at index zero for now
//    pathAnalyzer->computeNavigation(controllingPlayer);
    
    
}

std::vector<Player *> Team::getTeammatesForPlayer(Player *uPlayer){
    
    std::vector<Player*> teammates;
    
    for(const auto &n:getPlayers()){
        
        if (n!=uPlayer) {
            teammates.push_back(n);
        }
        
    }
    
    return teammates;
}

void Team::setControllingPlayer(Player *uPlayer){
    
    controllingPlayer=uPlayer;
    
}

Player *Team::getControllingPlayer(){
    return controllingPlayer;
}


void Team::computeFormationPosition(){

    formationPosition.clear();
    
    float radius=15.0;

    for(int i=1;i<=getPlayers().size();i++){

        float x=radius*cos(i*U4DEngine::PI/2.0);
        float z=radius*sin(i*U4DEngine::PI/2.0);

        U4DEngine::U4DVector3n pos(x,0.0,z);

        pos+=(startingPosition+controllingPlayer->getAbsolutePosition());

        formationPosition.push_back(pos);

    }

}

std::vector<U4DEngine::U4DVector3n> Team::getFormationPosition(){
    return formationPosition;
}

U4DEngine::U4DVector3n Team::getFormationPositionAtIndex(int uIndex){
    
    U4DEngine::U4DVector3n position;
    
    if(formationPosition.size()>0){
        position=formationPosition.at(uIndex);
    }
    
    return position;
}
