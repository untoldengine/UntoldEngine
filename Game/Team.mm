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

Team::Team():controllingPlayer(nullptr){
    
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
    
    players.push_back(uPlayer);
    
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

