//
//  PlayAnalyzer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/2/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "PlayAnalyzer.h"
#include "Player.h"
#include "Team.h"
#include "Ball.h"

PlayAnalyzer* PlayAnalyzer::instance=0;

PlayAnalyzer::PlayAnalyzer(){
    
}

PlayAnalyzer::~PlayAnalyzer(){
    
}

PlayAnalyzer* PlayAnalyzer::sharedInstance(){
    
    if (instance==0) {
        
        instance=new PlayAnalyzer();
        
    }
    
    return instance;
}

Player *PlayAnalyzer::closestTeammateToIntersectBall(Player *uPlayer){
    
    Ball *ball=Ball::sharedInstance();

    float maxDistanceToBall=1000.0;
    Player *closestTeammate=nullptr;

    Team *team=uPlayer->getTeam();
    
    for (const auto &n:team->getTeammatesForPlayer(uPlayer)) {

        //distace to ball
        float d=(ball->getAbsolutePosition()-n->getAbsolutePosition()).magnitude();

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
