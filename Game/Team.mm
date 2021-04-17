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

Team::Team():controllingPlayer(nullptr),startingPosition(0.0,0.0,0.0),playerIndex(0),markingPlayer(nullptr){
    
    //Create the callback. Notice that you need to provide the name of the class
    analyzerScheduler=new U4DEngine::U4DCallback<Team>;
    
    //create the timer
    analyzerTimer=new U4DEngine::U4DTimer(analyzerScheduler);
    
    //Create the callback. Notice that you need to provide the name of the class
    formationScheduler=new U4DEngine::U4DCallback<Team>;
    
    //create the timer
    formationTimer=new U4DEngine::U4DTimer(formationScheduler);
    
    
}

Team::~Team(){
    
    //In the class destructor,  make sure to delete the U4DCallback and U4DTimer as follows.
    //Make sure that before deleting the scheduler and timer, to first unsubscribe the timer.
    
    analyzerScheduler->unScheduleTimer(analyzerTimer);
    formationScheduler->unScheduleTimer(formationTimer);
    
    delete analyzerScheduler;
    delete analyzerTimer;
    
    delete formationScheduler;
    delete formationTimer;
    
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
    
    analyzerScheduler->scheduleClassWithMethodAndDelay(this, &Team::analyzeField, analyzerTimer, 0.2,true);
    formationScheduler->scheduleClassWithMethodAndDelay(this, &Team::updateFormation, formationTimer, 0.7,true);
    
}

void Team::updateFormation(){
    
    static bool home=false;
    static bool formation=false;
    
    if (formation==false) {
        
        if (home==false) {
            
            //send formation to home
            U4DEngine::U4DVector3n homePosition(0.0,0.0,2.0);
            
            formationManager.computeFormationPosition(homePosition);
            
            for(auto &n:getPlayers()){
                
                //send message to player
                MessageDispatcher *messageDispatcher=MessageDispatcher::sharedInstance();

                messageDispatcher->sendMessage(0.0, this, n, msgFormation);
                
            }
            
            home=true;
            
        }else{
            
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
            
        }
        
        formation=true;
        
    }else{
        
        for(auto &n:getPlayers()){

            //send message to player
            MessageDispatcher *messageDispatcher=MessageDispatcher::sharedInstance();

            messageDispatcher->sendMessage(0.0, this, n, msgWander);

        }
        
        formation=false;
    }
    
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
    
        //get closest player to intersect the ball
        PlayAnalyzer *playAnalyzer=PlayAnalyzer::sharedInstance();

        Player *teammate=playAnalyzer->closestTeammateToIntersectBall(this);

        //send message to player
        MessageDispatcher *messageDispatcher=MessageDispatcher::sharedInstance();
    
        messageDispatcher->sendMessage(0.0, this, teammate, msgMark);
        
    
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
