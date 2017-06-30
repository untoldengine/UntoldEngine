//
//  U11AttackSystem.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/3/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11AttackSystem.h"
#include "U11MessageDispatcher.h"
#include "U11SpaceAnalyzer.h"
#include "U11Player.h"
#include "U11Team.h"
#include "U11FormationInterface.h"
#include "U11TriangleManager.h"
#include "U11TriangleEntity.h"
#include "U11AISystem.h"


U11AttackSystem::U11AttackSystem(){
    
    scheduler=new U4DEngine::U4DCallback<U11AttackSystem>;
    supportAnalysisTimer=new U4DEngine::U4DTimer(scheduler);
    
}

U11AttackSystem::~U11AttackSystem(){
    
    delete scheduler;
    delete supportAnalysisTimer;
}

void U11AttackSystem::setTeam(U11Team *uTeam){
    
    team=uTeam;
    
}


//void U11AttackSystem::assignSupportPlayer(){
//    
//    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
//    
//    U11SpaceAnalyzer  spaceAnalyzer;
//    
//    //send message to new support player to support
//    team->setSupportPlayer(spaceAnalyzer.getClosestSupportPlayers(team).at(0));
//    
//    messageDispatcher->sendMessage(0.0, NULL, team->getSupportPlayer(), msgSupportPlayer);
//    
//}

void U11AttackSystem::computeSupportSpace(){
    
    
    if (team->getAISystem()->getPassingTheBall()==false) {
        
        U11TriangleManager triangleManager;
        
        triangleManager.initTriangleEntitiesComputation(team);
        
        //analyze play
        
        team->getAISystem()->getAttackStrategy()->analyzePlay(triangleManager.getTriangleEntityRoot());
        
        //set the position for each player
        
        U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
        
        for(auto n:triangleManager.getVertexNodeContainer()){
            
            U11Player *player=n.player;
            
            if (player!=team->getControllingPlayer()) {
                
                player->setSupportPosition(n.optimalPosition);
                
                messageDispatcher->sendMessage(0.0, NULL, player, msgRunToSupport);
                
            }
            
        }
        
        triangleManager.clearContainers();
        
    }
    
//    U11SpaceAnalyzer spaceAnalyzer;
//    
//    //assign support player
//    //assignSupportPlayer();
//    
//    //translate the formation
////    U11Player *controllingPlayer=team->getControllingPlayer();
////    
////    U4DEngine::U4DVector3n formationSupportSpace=(spaceAnalyzer.computeMovementRelToFieldGoal(team, controllingPlayer,formationDefenseSpace)).toVector();
////    
////    team->getTeamFormation()->translateFormation(formationSupportSpace);
////    
////    //change the home position for each player
////    
////    team->updateTeamFormationPosition();
////    
//    //assign the support players
//    std::vector<U4DEngine::U4DPoint3n> optimalSupportSpace=spaceAnalyzer.computeOptimalSupportSpace(team);
//    
//    U4DEngine::U4DVector3n supportSpaceVector=optimalSupportSpace.at(1).toVector();
//    //get player closest to support space
//    
//    U11Player *supportPlayer=spaceAnalyzer.getPlayersClosestToPosition(team, supportSpaceVector).at(0);
//    
//    team->setSupportPlayer(supportPlayer);
//
//    supportPlayer->setSupportPosition(optimalSupportSpace.at(1));
//    
//    
//    //send message to player to run to position
//    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
//    
//    messageDispatcher->sendMessage(0.0, NULL, supportPlayer, msgRunToSupport);
//    
//    //message all the players to get to their home position
//    
//    for(auto n:team->getTeammates()){
//        
//        if (n!=controllingPlayer && n!=supportPlayer1) {
//            messageDispatcher->sendMessage(0.0, NULL, n, msgRunToAttackFormation);
//        }
//        
//    }
//    
    
    
}

void U11AttackSystem::startComputeSupportSpaceTimer(){
    
    scheduler->scheduleClassWithMethodAndDelay(this, &U11AttackSystem::computeSupportSpace, supportAnalysisTimer, 2.0, true);
    
}

void U11AttackSystem::removeComputeSupportSpaceTimer(){
    
    scheduler->unScheduleTimer(supportAnalysisTimer);
    
}

