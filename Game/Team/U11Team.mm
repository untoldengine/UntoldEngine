//
//  U11Team.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/4/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11Team.h"
#include "U11HeapSort.h"
#include "U4DVector3n.h"
#include "U4DSegment.h"
#include <string>
#include "U4DNumerical.h"
#include "U11MessageDispatcher.h"
#include "UserCommonProtocols.h"
#include "U11FormationInterface.h"
#include "U11FormationEntity.h"
#include "U11Player.h"
#include "U11AISystem.h"
#include "U11AIStateInterface.h"
#include "U11AIStateManager.h"
#include "UserCommonProtocols.h"
#include "U11AIAttackState.h"
#include "U11AIDefenseState.h"

U11Team::U11Team(U4DEngine::U4DWorld *uWorld, U11AttackSystemInterface *uAttackSystem, U11DefenseSystemInterface *uDefenseSystem, U11RecoverSystemInterface *uRecoverSystem, U11AIAttackStrategyInterface *uAttackStrategy,int uFieldQuadrant, U11FormationInterface *uTeamFormation):controllingPlayer(NULL),supportPlayer(NULL),previousMainDefendingPlayer(NULL),previousMainControllingPlayer(NULL),mainDefendingPlayer(NULL),playerWithIndicator(NULL),selectManualDefendingPlayer(true){
    
    fieldQuadrant=uFieldQuadrant;
    
    teamFormation=uTeamFormation;
    
    teamFormation->init(uWorld, fieldQuadrant);
    
    aiSystem=new U11AISystem(this, uDefenseSystem, uAttackSystem, uRecoverSystem,uAttackStrategy);
    
    
}

U11Team::~U11Team(){
    
    delete aiSystem;
}

void U11Team::subscribe(U11Player* uPlayer){
    
    teammates.push_back(uPlayer);
    
    uPlayer->setFormationEntity(teamFormation->assignFormationEntity());
    
}

void U11Team::remove(U11Player* uPlayer){
    
    //get the player's name
    std::string name=uPlayer->getName();
    
    //unassign the formation entity
    uPlayer->getFormationEntity()->setAssigned(false);
    
    //remove player from the container
    teammates.erase(std::remove_if(teammates.begin(), teammates.end(), [&](U11Player* player){return player->getName().compare(name)==0;}),teammates.end());
    
}

void U11Team::changeState(U11AIStateInterface* uState){
    
    aiSystem->getStateManager()->changeState(uState);
}


std::vector<U11Player*> U11Team::getTeammates(){
    return teammates;
}

U11Team *U11Team::getOppositeTeam(){
    
    return oppositeTeam;
}

void U11Team::setOppositeTeam(U11Team *uTeam){
    
    oppositeTeam=uTeam;
}

void U11Team::setSoccerBall(U11Ball *uSoccerBall){
    
    soccerBall=uSoccerBall;
    
}

void U11Team::setFieldGoal(U11FieldGoal *uFieldGoal){
    
    fieldGoal=uFieldGoal;
}

U11Ball *U11Team::getSoccerBall(){
    
    return soccerBall;
    
}

U11FieldGoal *U11Team::getFieldGoal(){
    
    return fieldGoal;
}

U11Player* U11Team::getControllingPlayer(){
    
    return controllingPlayer;
    
}

void U11Team::setControllingPlayer(U11Player* uPlayer){
    
    resetDefendingPlayers();
    
    if (previousMainControllingPlayer!=NULL) {
        previousMainControllingPlayer->pauseExtremityCollision();
        //previousMainControllingPlayer->setEntityType(U4DEngine::MODELNOSHADOWS);
    }
    controllingPlayer=uPlayer;
    
    controllingPlayer->resumeExtremityCollision();
    
    controllingPlayer->setEntityType(U4DEngine::MODEL);
    setIndicatorForPlayer(controllingPlayer);
    
    previousMainControllingPlayer=controllingPlayer;
    
}

U11Player* U11Team::getSupportPlayer(){
    
    return supportPlayer;
    
}

void U11Team::setSupportPlayer(U11Player* uPlayer){
    
    supportPlayer=uPlayer;
    
}


void U11Team::setMainDefendingPlayer(U11Player *uPlayer){
    
    resetAttackingPlayers();
    
    if (previousMainDefendingPlayer!=NULL) {
        previousMainDefendingPlayer->pauseExtremityCollision();
        //previousMainDefendingPlayer->setEntityType(U4DEngine::MODELNOSHADOWS);
    }
    mainDefendingPlayer=uPlayer;
    
    mainDefendingPlayer->resumeExtremityCollision();
    mainDefendingPlayer->setEntityType(U4DEngine::MODEL);
    setIndicatorForPlayer(mainDefendingPlayer);
    
    previousMainDefendingPlayer=mainDefendingPlayer;
}

U11Player *U11Team::getMainDefendingPlayer(){
    
    return mainDefendingPlayer;
}


void U11Team::translateTeamToFormationPosition(){
    
    for(auto n:teammates){
        
        U4DEngine::U4DVector3n pos=n->getFormationEntity()->getAbsolutePosition();
        pos.y=n->getModelDimensions().y/2.0+0.3;
        
        U4DEngine::U4DPoint3n formationPosition=pos.toPoint();
        
        n->setFormationPosition(formationPosition);
        
        n->translateTo(pos);
        
    }
}

void U11Team::updateTeamFormationPosition(){
    
    for(auto n:teammates){
        
        U4DEngine::U4DPoint3n pos=(n->getFormationEntity()->getAbsolutePosition()).toPoint();
        pos.y=n->getModelDimensions().y/2.0+0.3;
        
        n->setFormationPosition(pos);
    
    }
    
}


void U11Team::setSupportDefendingPlayer(U11Player *uPlayer){
    
    supportDefendingPlayer=uPlayer;
}

U11Player *U11Team::getSupportDefendingPlayer(){
    
    return supportDefendingPlayer;
}


bool U11Team::handleMessage(Message &uMsg){
 
    return aiSystem->getStateManager()->handleMessage(uMsg);
    
}

U11FormationInterface *U11Team::getTeamFormation(){
    
    return teamFormation;
}

U11AISystem *U11Team::getAISystem(){
    
    return aiSystem;
}

U11Player *U11Team::getActivePlayer(){
    
    U11Player *player=nullptr;
    
    if (aiSystem->getStateManager()->getCurrentState()==U11AIDefenseState::sharedInstance()) {
        
        player=getMainDefendingPlayer();
        
    }else if (aiSystem->getStateManager()->getCurrentState()==U11AIAttackState::sharedInstance()){
        
        player=getControllingPlayer();
    }
    
    return player;
}

void U11Team::resetAttackingPlayers(){
    
    if (controllingPlayer!=nullptr) {
        
        controllingPlayer->pauseExtremityCollision();
        //controllingPlayer->setEntityType(U4DEngine::MODELNOSHADOWS);
        previousMainControllingPlayer=nullptr;
        
        
    }
    controllingPlayer=nullptr;
    supportPlayer=nullptr;
    
}

void U11Team::resetDefendingPlayers(){
    
    if (mainDefendingPlayer!=nullptr) {
        
        mainDefendingPlayer->pauseExtremityCollision();
        //mainDefendingPlayer->setEntityType(U4DEngine::MODELNOSHADOWS);
        previousMainDefendingPlayer=nullptr;
        
        
    }
    
    mainDefendingPlayer=nullptr;
    supportDefendingPlayer=nullptr;
    
    
    setManualDefendingPlayer(true);
}

void U11Team::setIndicatorForPlayer(U11Player *uPlayer){
    
    playerWithIndicator=uPlayer;
}

U11Player *U11Team::getIndicatorForPlayer(){
    
    if (playerWithIndicator!=nullptr) {
        return playerWithIndicator;
    }
}


bool U11Team::setManualDefendingPlayer(bool uValue){
    
    selectManualDefendingPlayer=uValue;
}

bool U11Team::getManualDefendingPlayer(){
    
    return selectManualDefendingPlayer;
}
