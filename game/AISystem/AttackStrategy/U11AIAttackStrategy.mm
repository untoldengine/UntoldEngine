//
//  U11AttackStrategy.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11AIAttackStrategy.h"
#include "U11Team.h"
#include "U11MessageDispatcher.h"
#include "U11SpaceAnalyzer.h"
#include "U11Player.h"
#include "UserCommonProtocols.h"

U11AIAttackStrategy::U11AIAttackStrategy(){
    
}

U11AIAttackStrategy::~U11AIAttackStrategy(){
    
}

void U11AIAttackStrategy::setTeam(U11Team *uTeam){
    
    team=uTeam;
    
}

void U11AIAttackStrategy::analyzePlay(){
    
    //get controlling player
    U11Player *controllingPlayer=team->getControllingPlayer();
    
    //get the player new dribble heading
    
    U11SpaceAnalyzer spaceAnalyzer;
    
    U4DEngine::U4DVector3n playerDribblingVector=spaceAnalyzer.computeOptimalDribblingVector(team);
    
    playerDribblingVector.normalize();
    
    playerDribblingVector.y=0.0;
    
    //get player heading vector
    U4DEngine::U4DVector3n playerHeading=controllingPlayer->getPlayerHeading();
    
    playerHeading.y=0.0;
    
    playerHeading.normalize();
    
    U11Player* threateningPlayer=controllingPlayer->getThreateningPlayer();
    
    //get the distance
    
    float distance=(controllingPlayer->getAbsolutePosition()-threateningPlayer->getAbsolutePosition()).magnitude();
    
    if (distance<15.0) {
        
        if (playerHeading.dot(threateningPlayer->getPlayerHeading())<-0.7) {
            
            //get the rotation axis
            U4DEngine::U4DVector3n rotationAxis=playerHeading.cross(playerDribblingVector);
            
            rotationAxis.normalize();
            
            playerDribblingVector=playerDribblingVector.rotateVectorAboutAngleAndAxis(60.0, rotationAxis);
            
        }
       
    }
    
    controllingPlayer->setBallKickDirection(playerDribblingVector);
    
    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
    
    messageDispatcher->sendMessage(0.0, nullptr, controllingPlayer, msgDribble);
    
    
}
