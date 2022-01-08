//
//  U4DTeam.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/15/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DTeam.h"
#include "U4DMessageDispatcher.h"

namespace U4DEngine{

    U4DTeam::U4DTeam():controllingPlayer(nullptr),playerIndex(0){
        
        //Create the callback. Notice that you need to provide the name of the class
        formationScheduler=new U4DEngine::U4DCallback<U4DTeam>;
        
        //create the timer
        formationTimer=new U4DEngine::U4DTimer(formationScheduler);
        
    }

    U4DTeam::~U4DTeam(){
        
    }

    void U4DTeam::initAnalyzerSchedulers(){
        
        
        formationScheduler->scheduleClassWithMethodAndDelay(this, &U4DTeam::updateFormation, formationTimer, 1.0,true);
        formationManager.computeHomePosition();
        //formationTimer->setPause(true);
        
        
    }

    void U4DTeam::addPlayer(U4DPlayer *uPlayer){
        
        uPlayer->addToTeam(this);
        players.push_back(uPlayer);
        
        uPlayer->setPlayerIndex(playerIndex++);
        
        U4DVector3n playerSpot=uPlayer->getAbsolutePosition();
        playerSpot.y=0.0;

        
        formationManager.spots.push_back(playerSpot);
        
        
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

    void U4DTeam::setControllingPlayer(U4DPlayer *uPlayer){
        
        controllingPlayer=uPlayer;
        
    }

    U4DPlayer *U4DTeam::getControllingPlayer(){
        return controllingPlayer;
    }

    void U4DTeam::updateFormation(){
        
        static bool formation=false;
        
        if (formation==false) {
            
            formationManager.computeFormationPosition(controllingPlayer->getAbsolutePosition());
        
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

}
