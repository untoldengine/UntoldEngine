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
#include "U11TriangleEntity.h"
#include "U11FieldGoal.h"
#include "U11AISystem.h"
#include "U11PlayerAttackState.h"
#include "U11PlayerDribbleState.h"

U11AIAttackStrategy::U11AIAttackStrategy(){
    
}

U11AIAttackStrategy::~U11AIAttackStrategy(){
    
}

void U11AIAttackStrategy::setTeam(U11Team *uTeam){
    
    team=uTeam;
    
}

void U11AIAttackStrategy::analyzePlay(U11TriangleEntity *uTriangleEntityRoot){
    
    U11SpaceAnalyzer spaceAnalyzer;
    U11FieldGoal *fieldGoal=team->getOppositeTeam()->getFieldGoal();
    U4DEngine::U4DVector3n fieldGoalPosition=fieldGoal->getAbsolutePosition();
    fieldGoalPosition.y=0;
    
    //1. analyze node with clearest sight to goal
    
    TriangleNodeEntity triangleNodeEntity=getOptimalTriangleEntity(uTriangleEntityRoot);
    
    //2. has all players of the node entity reached their support position
    
    U11Player *controllingPlayer=team->getControllingPlayer();
    
    if(hasPlayersReachedSupportPosition(triangleNodeEntity.triangleEntity)&& (controllingPlayer->getCurrentState()==U11PlayerAttackState::sharedInstance()|| controllingPlayer->getCurrentState()==U11PlayerDribbleState::sharedInstance())){
        
        std::vector<U11Player*> players=triangleNodeEntity.triangleEntity->getTriangleEntityPlayers();
        
        //3. check the number of players inside triangle
        if (triangleNodeEntity.playersInsideEntity>1) {
            
            std::cout<<"triangle threat"<<std::endl;
            
        }else if (triangleNodeEntity.playersInsideEntity<=1){
            
            //chose best support player to pass the ball to
            
            //get the player closest to the goal
            std::vector<U11Player*> closestPlayers=spaceAnalyzer.getPlayersClosestToPosition(fieldGoalPosition,players);
            
            
            //determine to whom it is safer to pass ball
            
            U11Player *supportPlayer=closestPlayers.at(0);
            
            if (supportPlayer==team->getControllingPlayer()) {
                
                supportPlayer=closestPlayers.at(1);
                
            }
            
            
//            team->setSupportPlayer(supportPlayer);
//            
//            //pass the ball
//            pass();
            
        }
        
    }else{
       
        
    }
    
    
}

bool U11AIAttackStrategy::hasPlayersReachedSupportPosition(U11TriangleEntity *uTriangleEntity){
    
    bool reachedSupport=false;
    
    std::vector<U11Player*> players=uTriangleEntity->getTriangleEntityPlayers();
    
    for(auto n:players){
        
        if (n->hasReachedPosition(n->getSupportPosition(), withinSupportDistance)) {
            
            reachedSupport=true;
        }else{
            reachedSupport=false;
        }
    }
    
    return reachedSupport;
    
}

TriangleNodeEntity U11AIAttackStrategy::getOptimalTriangleEntity(U11TriangleEntity *uTriangleEntityRoot){
    
    TriangleNodeEntity triangleNodeEntity;
    
    U11TriangleEntity *child=uTriangleEntityRoot->next->getLastChild();
    
    float totalScore=FLT_MAX;
    
    //get field goal info to build a line of sight
    U11FieldGoal *fieldGoal=team->getOppositeTeam()->getFieldGoal();
    
    U4DEngine::U4DPoint3n fieldGoalPosition=fieldGoal->getAbsolutePosition().toPoint();
    
    fieldGoalPosition.y=0.0;
    fieldGoalPosition.z=0.0;
    
    float zFieldGoal=fieldGoal->getModelDimensions().z/2.0;
    
    U4DEngine::U4DPoint3n fieldGoalPointA(fieldGoalPosition.x,fieldGoalPosition.y,zFieldGoal);
    U4DEngine::U4DPoint3n fieldGoalPointB(fieldGoalPosition.x,fieldGoalPosition.y,-zFieldGoal);
    
    while (child !=nullptr) {
        
        U4DEngine::U4DPoint3n triangleEntityCentroid=child->getTriangleEntityCentroid();
        
        //build triangle to goal
        U4DEngine::U4DTriangle triangleToGoal(fieldGoalPointA, fieldGoalPointB, triangleEntityCentroid);
        
        //get triangle entity geometry
        U4DEngine::U4DTriangle triangleEntityGeometry=child->getTriangleEntityGeometry();
        
        int playersInSight=0;
        float distanceToGoal=0.0;
        int playersInsideEntity=0.0;
        
        for(auto n:team->getOppositeTeam()->getTeammates()){
            
            U4DEngine::U4DPoint3n playerPosition=n->getCurrentPosition().toPoint();
            
            //Test 1. get triangle with clearest sight to goal
            
            if (triangleToGoal.isPointOnTriangle(playerPosition)) {
                
                playersInSight++;
            }
            
            //Test 2. Get number of players inside entity
            if (triangleEntityGeometry.isPointOnTriangle(playerPosition)) {
                
                playersInsideEntity++;
            }
            
        }
        
        //Test 3. Get distance of triangle node to field goal
        distanceToGoal=(fieldGoalPosition-triangleEntityCentroid).magnitude();
        
        
        //add up total and compare
        float triangleEntityScore=playersInSight+1000*playersInsideEntity+distanceToGoal;
        
        if (triangleEntityScore<=totalScore) {
            
            triangleNodeEntity.triangleEntity=child;
            triangleNodeEntity.distanceToGoal=distanceToGoal;
            triangleNodeEntity.playersInsideEntity=playersInsideEntity;
            triangleNodeEntity.playersInSightToGoal=playersInSight;
            
            totalScore=triangleEntityScore;
        }
        
        child=child->getPrevSibling();
    }
    
    return triangleNodeEntity;
}

bool U11AIAttackStrategy::shouldPassForward(){
    
    //space analyzer
    U11SpaceAnalyzer spaceAnalyzer;
    
    //get the support players
    U11Player *support=team->getSupportPlayer();
    
    //for each player get the number of opponents threatening && is it closer to the goal than the controlling player
    
    if (spaceAnalyzer.analyzeIfPlayerIsCloserToGoalThanMainPlayer(team, support)) {
        
        std::cout<<"Should pass"<<std::endl;
        
        return true;
        
    }
    
    return false;
    
    
}

void U11AIAttackStrategy::pass(){
    
    //get the support players
    U11Player *supportPlayer=team->getSupportPlayer();
    
    U11Player *controllingPlayer=team->getControllingPlayer();
    
    U4DEngine::U4DVector3n supportPosition=supportPlayer->getCurrentPosition();
    
    U4DEngine::U4DVector3n controllingPlayerPosition=controllingPlayer->getCurrentPosition();
    
    U4DEngine::U4DVector3n distanceBetweenPlayers=supportPosition-controllingPlayerPosition;
    
    distanceBetweenPlayers.normalize();
    
    //get player heading vector
    U4DEngine::U4DVector3n playerHeading=controllingPlayer->getPlayerHeading();
    
    playerHeading.y=0.0;
    
    playerHeading.normalize();
    
    float angle=playerHeading.angle(distanceBetweenPlayers);
    
    U4DEngine::U4DVector3n rotationAxis=playerHeading.cross(distanceBetweenPlayers);
    
    rotationAxis.normalize();

    U4DEngine::U4DVector3n kickingDirection=playerHeading.rotateVectorAboutAngleAndAxis(angle, rotationAxis);
    
    controllingPlayer->setBallKickDirection(kickingDirection);
    
    int ballSpeed=50;
    
    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
    
    messageDispatcher->sendMessage(0.0, nullptr, controllingPlayer, msgPassBall,(void*)&ballSpeed);
    
}

void U11AIAttackStrategy::dribble(){
    
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
