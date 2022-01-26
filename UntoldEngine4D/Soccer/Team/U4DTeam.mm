//
//  U4DTeam.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/15/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DTeam.h"
#include "U4DMessageDispatcher.h"
#include "U4DTeamStateInterface.h"
#include "U4DTeamStateManager.h"
#include "U4DTeamStateIdle.h"

namespace U4DEngine{

    U4DTeam::U4DTeam(std::string uName):name(uName),activePlayer(nullptr),playerIndex(0),enableDefenseAnalyzer(false),aiTeam(false){
        
        //Create the callback. Notice that you need to provide the name of the class
        formationScheduler=new U4DEngine::U4DCallback<U4DTeam>;
        
        //create the timer
        formationTimer=new U4DEngine::U4DTimer(formationScheduler);
        
        //Create the callback. Notice that you need to provide the name of the class
        defenseScheduler=new U4DEngine::U4DCallback<U4DTeam>;
        
        //create the timer
        defenseTimer=new U4DEngine::U4DTimer(defenseScheduler);
        
        //Create the callback. Notice that you need to provide the name of the class
        analyzerFieldScheduler=new U4DEngine::U4DCallback<U4DTeam>;
        
        //create the timer
        analyzerFieldTimer=new U4DEngine::U4DTimer(analyzerFieldScheduler);
        
        //set state manager
        stateManager=new U4DTeamStateManager(this);
        
        changeState(U4DTeamStateIdle::sharedInstance());
        
        
    }

    U4DTeam::~U4DTeam(){
        
        defenseScheduler->unScheduleTimer(defenseTimer);
        formationScheduler->unScheduleTimer(formationTimer);
        analyzerFieldScheduler->unScheduleTimer(formationTimer);
        
        delete defenseScheduler;
        delete defenseTimer;
        
        delete formationScheduler;
        delete formationTimer;
        
        delete analyzerFieldScheduler;
        delete analyzerFieldTimer;
        
        delete stateManager;
    }

    void U4DTeam::initAnalyzerSchedulers(){
        
        formationManager.computeHomePosition();
        formationScheduler->scheduleClassWithMethodAndDelay(this, &U4DTeam::updateFormation, formationTimer, 1.0,true);
        
        //formationTimer->setPause(true);
        
        
        defenseScheduler->scheduleClassWithMethodAndDelay(this, &U4DTeam::startAnalyzingDefense, defenseTimer, 0.05,true);
        
        analyzerFieldScheduler->scheduleClassWithMethodAndDelay(this, &U4DTeam::analyzeField, analyzerFieldTimer, 1.0,true);
        
        defenseTimer->setPause(true);
        
        analyzerFieldTimer->setPause(true);
        
    }

    void U4DTeam::update(double dt){
        stateManager->update(dt);
    }


    U4DTeamStateInterface *U4DTeam::getCurrentState(){
        return stateManager->getCurrentState();
    }


    U4DTeamStateInterface *U4DTeam::getPreviousState(){
        return stateManager->getPreviousState();
    }

    void U4DTeam::changeState(U4DTeamStateInterface *uState){
        stateManager->safeChangeState(uState);
    }

    void U4DTeam::addPlayer(U4DPlayer *uPlayer){
        
        uPlayer->addToTeam(this);
        players.push_back(uPlayer);
        
        uPlayer->setPlayerIndex(playerIndex++);
        
    }

    void U4DTeam::removePlayer(U4DPlayer *uPlayer){
        
        players.erase(std::remove_if(players.begin(),players.end(),[&](U4DPlayer *playerToRemove){return playerToRemove==uPlayer;}),players.end());
        
    }

    std::vector<U4DPlayer *> U4DTeam::getPlayers(){
        
        return players;
        
    }

    std::vector<U4DPlayer *> U4DTeam::getTeammatesForPlayer(U4DPlayer *uPlayer){
        
        std::vector<U4DPlayer*> teammates;
        
        for(const auto &n:getPlayers()){
            
            if (n!=uPlayer) {
                teammates.push_back(n);
            }
            
        }
        
        return teammates;
        
    }

    void U4DTeam::setActivePlayer(U4DPlayer *uPlayer){
        
        activePlayer=uPlayer;
        
    }

    U4DPlayer *U4DTeam::getActivePlayer(){
        return activePlayer;
    }

    void U4DTeam::loadPlayersFormations(){
            
        for(const auto n:players){
            
            U4DVector3n playerSpot=n->getAbsolutePosition();
            playerSpot.y=0.0;

            
            formationManager.spots.push_back(playerSpot);
        
        }
    
    }

    void U4DTeam::updateFormation(){
        
        static bool formation=false;
        
        if (formation==false) {
            
            formationManager.computeFormationPosition(activePlayer->getAbsolutePosition());
        
//            for(auto &n:getPlayers()){
//
//                //send message to player
//                U4DMessageDispatcher *messageDispatcher=U4DMessageDispatcher::sharedInstance();
//
//                if(n!=controllingPlayer){
//                    messageDispatcher->sendMessage(0.0, this, n, msgFormation);
//                }
//
//
//            }
            
            formation=true;
        }else{
            
            for(auto &n:getPlayers()){

                //send message to player
//                U4DMessageDispatcher *messageDispatcher=U4DMessageDispatcher::sharedInstance();
//
//                messageDispatcher->sendMessage(0.0, this, n, msgWander);

            }
            
            formation=false;
        }
    }

void U4DTeam::startAnalyzingDefense(){
    enableDefenseAnalyzer=true;
}

void U4DTeam::analyzeField(){
    
    U4DFieldAnalyzer *fieldAnalyzer=U4DFieldAnalyzer::sharedInstance();

    fieldAnalyzer->analyzeField(this,oppositeTeam);

    //get nav path
    U4DPathAnalyzer *pathAnalyzer=U4DPathAnalyzer::sharedInstance();

    //Get player at index zero for now
    pathAnalyzer->computeNavigation(activePlayer);
    
}

void U4DTeam::setOppositeTeam(U4DTeam *uTeam){
    
    oppositeTeam=uTeam;
    
}

U4DTeam *U4DTeam::getOppositeTeam(){
    return oppositeTeam;
}

std::string U4DTeam::getName(){
    return name;
}

}
