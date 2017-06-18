//
//  U11RecoverSystem.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/4/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11RecoverSystem.h"
#include "U11MessageDispatcher.h"
#include "U11SpaceAnalyzer.h"
#include "U11Player.h"
#include "U11Team.h"
#include "U11FormationInterface.h"

U11RecoverSystem::U11RecoverSystem(){
    
    scheduler=new U4DEngine::U4DCallback<U11RecoverSystem>;
    closestPlayerAnalysisTimer=new U4DEngine::U4DTimer(scheduler);
    
}

U11RecoverSystem::~U11RecoverSystem(){
    
    delete scheduler;
    delete closestPlayerAnalysisTimer;
}

void U11RecoverSystem::setTeam(U11Team *uTeam){
    
    team=uTeam;
    
}

void U11RecoverSystem::computeClosestPlayerToBall(){
    
    //Analyze the player closer to the balls trajectory
    
    U11SpaceAnalyzer spaceAnalyzer;
    
    U11Player *player=spaceAnalyzer.getClosestPlayersToBall(team).at(0);
    
    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
    
    messageDispatcher->sendMessage(0.0, nullptr, player, msgIntercept);
    
}

void U11RecoverSystem::startComputeClosestPlayerTimer(){
    
    scheduler->scheduleClassWithMethodAndDelay(this, &U11RecoverSystem::computeClosestPlayerToBall, closestPlayerAnalysisTimer, 0.8, false);
    
}

void U11RecoverSystem::removeComputeClosestPlayerTimer(){
    
    scheduler->unScheduleTimer(closestPlayerAnalysisTimer);
}
