//
//  U11RecoverAISystem.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11RecoverAISystem.h"
#include "U11MessageDispatcher.h"
#include "U11SpaceAnalyzer.h"
#include "U11Player.h"
#include "U11Team.h"
#include "U11FormationInterface.h"

U11RecoverAISystem::U11RecoverAISystem(){
    
    scheduler=new U4DEngine::U4DCallback<U11RecoverAISystem>;
    closestPlayerAnalysisTimer=new U4DEngine::U4DTimer(scheduler);
    
}

U11RecoverAISystem::~U11RecoverAISystem(){
    
    delete scheduler;
    delete closestPlayerAnalysisTimer;
}

void U11RecoverAISystem::setTeam(U11Team *uTeam){
    
    team=uTeam;
    
}

void U11RecoverAISystem::computeClosestPlayerToBall(){
    
        U11SpaceAnalyzer spaceAnalyzer;
    
        U11Player *player=spaceAnalyzer.analyzeClosestPlayersToBall(team).at(0);
    
        U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
    
        messageDispatcher->sendMessage(0.0, nullptr, player, msgIntercept);
    
}

void U11RecoverAISystem::startComputeClosestPlayerTimer(){
    
    scheduler->scheduleClassWithMethodAndDelay(this, &U11RecoverAISystem::computeClosestPlayerToBall, closestPlayerAnalysisTimer, 2.0, false);
    
}

void U11RecoverAISystem::removeComputeClosestPlayerTimer(){
    
    scheduler->unScheduleTimer(closestPlayerAnalysisTimer);
}

