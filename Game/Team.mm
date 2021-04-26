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
#include "PlayAnalyzer.h"
#include "Constants.h"
#include "MessageDispatcher.h"
#include "TeamStateManager.h"
#include "TeamStateInterface.h"
#include "TeamStateIdle.h"

Team::Team():controllingPlayer(nullptr),startingPosition(0.0,0.0,0.0),playerIndex(0),markingPlayer(nullptr),enableDefenseAnalyzer(false),aiTeam(false){
    
    //Create the callback. Notice that you need to provide the name of the class
    defenseScheduler=new U4DEngine::U4DCallback<Team>;
    
    //create the timer
    defenseTimer=new U4DEngine::U4DTimer(defenseScheduler);
    
    //Create the callback. Notice that you need to provide the name of the class
    formationScheduler=new U4DEngine::U4DCallback<Team>;
    
    //create the timer
    formationTimer=new U4DEngine::U4DTimer(formationScheduler);
    
    //set state manager
    stateManager=new TeamStateManager(this); 
    
    changeState(TeamStateIdle::sharedInstance());
    
    startAnalyzing();
}

Team::~Team(){
    
    //In the class destructor,  make sure to delete the U4DCallback and U4DTimer as follows.
    //Make sure that before deleting the scheduler and timer, to first unsubscribe the timer.
    
    defenseScheduler->unScheduleTimer(defenseTimer);
    formationScheduler->unScheduleTimer(formationTimer);
    
    delete defenseScheduler;
    delete defenseTimer;
    
    delete formationScheduler;
    delete formationTimer;
    
}

void Team::update(double dt){
    stateManager->update(dt);
}

TeamStateInterface *Team::getCurrentState(){
    return stateManager->getCurrentState();
}

TeamStateInterface *Team::getPreviousState(){
    return stateManager->getPreviousState();
}

void Team::changeState(TeamStateInterface *uState){
    stateManager->safeChangeState(uState);
}

void Team::handleMessage(Message &uMsg){
    stateManager->handleMessage(uMsg);
}

void Team::addPlayer(Player *uPlayer){
    
    uPlayer->addToTeam(this);
    players.push_back(uPlayer);
    
}

std::vector<Player *> Team::getPlayers(){
    
    return players;
    
}

void Team::setOppositeTeam(Team *uTeam){
    
    oppositeTeam=uTeam;
    
}

void Team::startAnalyzing(){
    
    defenseScheduler->scheduleClassWithMethodAndDelay(this, &Team::startAnalyzingDefense, defenseTimer, 0.15,true);
    formationScheduler->scheduleClassWithMethodAndDelay(this, &Team::updateFormation, formationTimer, 0.7,true);
    
    defenseTimer->setPause(true);
    formationTimer->setPause(true);
}

void Team::updateFormation(){
    
    static bool formation=false;
    
    if (formation==false) {
        
        U4DEngine::U4DVector3n v(0.0,0.0,0.0);
    
        for(auto &n:getPlayers()){

            v+=n->getAbsolutePosition();
        }
    
        v/=getPlayers().size();

        v.y=0;

    
        formationManager.computeFormationPosition(v);
    
        for(auto &n:getPlayers()){
            
            //send message to player
            MessageDispatcher *messageDispatcher=MessageDispatcher::sharedInstance();

            messageDispatcher->sendMessage(0.0, this, n, msgFormation);
            
        }
        
        //formation=true;
    }else{
        
        for(auto &n:getPlayers()){

            //send message to player
            MessageDispatcher *messageDispatcher=MessageDispatcher::sharedInstance();

            messageDispatcher->sendMessage(0.0, this, n, msgWander);

        }
        
        formation=false;
    }
       
}

void Team::startAnalyzingDefense(){
    enableDefenseAnalyzer=true;
}

void Team::analyzeField(){
    
//    FieldAnalyzer *fieldAnalyzer=FieldAnalyzer::sharedInstance();
//
//    fieldAnalyzer->analyzeField(this,oppositeTeam);
//
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

//void Team::computeFormationPosition(){
//
//    int playerIndex=(int)(getPlayers().size()-1);
//    
//    if (formationManager!=nullptr) {
//        
//        U4DEngine::U4DEntity *child=formationManager->next;
//        
//        while (child!=nullptr) {
//            
//            formationPosition[playerIndex]=child->getAbsolutePosition();
//            
//            playerIndex--;
//            child=child->next;
//        }
//        
//    }
//
//}


void Team::setMarkingPlayer(Player *uPlayer){
    
    markingPlayer=uPlayer;
    
}

Player *Team::getMarkingPlayer(){
    
    return markingPlayer;
    
}

void Team::sendTeamHome(){
    
    
    
}
