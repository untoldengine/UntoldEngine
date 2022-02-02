//
//  U4DPlayAnalyzer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/15/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayAnalyzer.h"
#include "U4DPlayer.h"
#include "U4DTeam.h"
#include "U4DBall.h"
#include "U4DGameConfigs.h"

namespace U4DEngine {

U4DPlayAnalyzer* U4DPlayAnalyzer::instance=0;

U4DPlayAnalyzer::U4DPlayAnalyzer(){
    
}

U4DPlayAnalyzer::~U4DPlayAnalyzer(){
    
}

U4DPlayAnalyzer* U4DPlayAnalyzer::sharedInstance(){
    
    if (instance==0) {
        
        instance=new U4DPlayAnalyzer();
        
    }
    
    return instance;
}

U4DPlayer *U4DPlayAnalyzer::closestTeammateToIntersectBall(U4DTeam *uTeam){
    
    U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
    U4DBall *ball=U4DBall::sharedInstance();

    float maxDistanceToBall=1000.0;
    U4DPlayer *closestTeammate=nullptr;

    U4DVector3n ballEstimatedPosition=ball->getAbsolutePosition()+ball->kickDirection*gameConfigs->getParameterForKey("passInterceptionParam");
   
    
    for (const auto &n:uTeam->getPlayers()) {

        //distace to ball
        float d=(ballEstimatedPosition-n->getAbsolutePosition()).magnitude();

        if(d<maxDistanceToBall){

            maxDistanceToBall=d;
            closestTeammate=n;

        }
    }

    return closestTeammate;
    
}

U4DPlayer *U4DPlayAnalyzer::closestTeammateToIntersectBall(U4DPlayer *uPlayer){
    
    U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
    
    U4DBall *ball=U4DBall::sharedInstance();

    float maxDistanceToBall=1000.0;
    U4DPlayer *closestTeammate=nullptr;

    U4DTeam *team=uPlayer->getTeam();

    U4DVector3n ballEstimatedPosition=ball->getAbsolutePosition()+ball->kickDirection*gameConfigs->getParameterForKey("passInterceptionParam");
    
    for (const auto &n:team->getTeammatesForPlayer(uPlayer)) {

        //distace to ball
        float d=(ballEstimatedPosition-n->getAbsolutePosition()).magnitude();

        if((n!=uPlayer)&&(d<maxDistanceToBall)){

            maxDistanceToBall=d;
            closestTeammate=n;

        }
    }

    return closestTeammate;
    
    
//    if(closestPlayer!=nullptr){
//
//        //chose the player closest to intersect the ball. For now, just do this.
//        closestPlayer->changeState(pursuit);
//
//
//    }
    
}

    void U4DPlayAnalyzer::analyzeActionToMake(){
        
        //pass, dribble or shoot?
        
        
        
    }

}
