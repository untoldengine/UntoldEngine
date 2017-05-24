//
//  U11SpaceAnalyzer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/29/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11SpaceAnalyzer.h"
#include "U11HeapSort.h"
#include "U11Team.h"
#include "U11FieldGoal.h"
#include "U4DSegment.h"
#include "UserCommonProtocols.h"

U11SpaceAnalyzer::U11SpaceAnalyzer(){
    
    //set the playing field aabb
    
    U4DEngine::U4DPoint3n minPlayingFieldBound(-playingFieldLength/2.0, -1.0, -playingFieldWidth/2.0);
    U4DEngine::U4DPoint3n maxPlayingFieldBound(playingFieldLength/2.0, 1.0, playingFieldWidth/2.0);
    
    playingField.setMinPoint(minPlayingFieldBound);
    playingField.setMaxPoint(maxPlayingFieldBound);
    
}

U11SpaceAnalyzer::~U11SpaceAnalyzer(){
    
    
}

std::vector<U11Player*> U11SpaceAnalyzer::analyzePlayersDistanceToPosition(U11Team *uTeam, U4DEngine::U4DVector3n &uPosition){
    
    //get each support player into a node with its distance to uPosition
    
    uPosition.y=0;
    
    //set up the heapsort container
    std::vector<U11Node> heapContainer;
    
    for(auto n:uTeam->getTeammates()){
        
        if (n!=uTeam->getControllingPlayer()) {
            
            U4DEngine::U4DVector3n playerPosition=n->getAbsolutePosition();
            playerPosition.y=0;
            
            float distance=(uPosition-playerPosition).magnitude();
            
            //create a node
            U11Node node;
            node.player=n;
            node.data=distance;
            
            heapContainer.push_back(node);
            
        }
        
    }
    
    //sort the players closer to the position
    
    U11HeapSort heapSort;
    heapSort.heapify(heapContainer);
    
    std::vector<U11Player*> sortPlayers;
    
    for(auto n:heapContainer){
        
        sortPlayers.push_back(n.player);
    }
    
    return sortPlayers;
    
}

std::vector<U11Player*> U11SpaceAnalyzer::analyzeClosestPlayersAlongLine(U11Team *uTeam, U4DEngine::U4DSegment &uLine){
    
    //get each support player into a node with its distance to uPosition
    
    uLine.pointA.y=0.0;
    uLine.pointB.y=0.0;
    
    //set up the heapsort container
    std::vector<U11Node> heapContainer;
    
    for(auto n:uTeam->getTeammates()){
        
        if (n!=uTeam->getControllingPlayer()) {
            
            U4DEngine::U4DPoint3n playerPosition=n->getAbsolutePosition().toPoint();
            playerPosition.y=0;
            
            float distance=uLine.sqDistancePointSegment(playerPosition);
            
            //create a node
            U11Node node;
            node.player=n;
            node.data=distance;
            
            heapContainer.push_back(node);
            
        }
        
    }
    
    //sort the players closer to the position
    
    U11HeapSort heapSort;
    
    heapSort.heapify(heapContainer);
    
    std::vector<U11Player*> sortPlayers;
    
    for(auto n:heapContainer){
        
        sortPlayers.push_back(n.player);
    }
    
    return sortPlayers;
}


U4DEngine::U4DPoint3n U11SpaceAnalyzer::analyzeClosestSupportSpaceAlongLine(U4DEngine::U4DVector3n &uLine, std::vector<SupportNode> &uSupportNodes, U4DEngine::U4DVector3n &uControllingPlayerPosition){
    
    U4DEngine::U4DVector3n lineVector=uLine;
    lineVector.normalize();
    
    U4DEngine::U4DVector3n positionVector;
    
    //set up the heapsort container
    std::vector<U11Node> heapContainer;
    
    for(auto n:uSupportNodes){
        
        positionVector=n.position.toVector();
        positionVector=(positionVector-uControllingPlayerPosition)/supportMaximumDistanceToPlayer;
        positionVector.normalize();
        
        float dotProduct=positionVector.dot(uLine);
        dotProduct=1.0-dotProduct;
        
        //create a node
        U11Node node;
        node.data=dotProduct;
        node.supportPoint=n.position;
        heapContainer.push_back(node);
        
    }
    
    //sort the dot product from smaller to largest
    U11HeapSort heapsort;
    heapsort.heapify(heapContainer);
    
    //return the closest dot product
    return heapContainer.at(0).supportPoint;
    
}

std::vector<U4DEngine::U4DPoint3n> U11SpaceAnalyzer::computeOptimalSupportSpace(U11Team *uTeam){
    
    //compute the nodes position
    
    //get the controlling player heading
    U11Player *controllingPlayer=uTeam->getControllingPlayer();
    U4DEngine::U4DVector3n playerHeading=controllingPlayer->getPlayerHeading();
    U4DEngine::U4DVector3n controllingPlayerPosition=controllingPlayer->getAbsolutePosition();
    controllingPlayerPosition.y=0.0;
    
    playerHeading.normalize();
    
    
    //get the right hand heading of the player
    U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
    
    U4DEngine::U4DVector3n rightHandHeading=playerHeading.cross(upVector);
    
    rightHandHeading.normalize();
    
    for(int i=0;i<maximumSupportPoints;i++){
        
        U4DEngine::U4DVector3n position=rightHandHeading.rotateVectorAboutAngleAndAxis(i*supportPointsSeparation, upVector);
        
        SupportNode supportNode;
        supportNode.position=position.toPoint()*supportMaximumDistanceToPlayer+controllingPlayerPosition.toPoint();
        
        supportNodes.push_back(supportNode);
        
    }
    
    //score each position
    
    //get opposite players
    U11Team *oppositeTeam=uTeam->getOppositeTeam();
    
    //compute closest players to controlling player
    std::vector<U11Player*> oppositePlayers=analyzePlayersDistanceToPosition(oppositeTeam, controllingPlayerPosition);
    
    if (oppositePlayers.size()>4) {
        oppositePlayers.resize(4);
    }
    
    //Test 1. check if it passing angle does not intersept an opponent and if it lands outside the playing field
    for(auto &n:supportNodes){
        
        for(auto m:oppositePlayers){
            
            //get the segment between the support space and controlling player
            U4DEngine::U4DPoint3n pointA=controllingPlayerPosition.toPoint();
            U4DEngine::U4DPoint3n pointB=n.position;
            U4DEngine::U4DSegment passingAngle(pointB,pointA);
            
            if (!m->getUpdatedPlayerSpaceBox().intersectionWithSegment(passingAngle) && playingField.isPointInsideAABB(pointB)) {
                
                //set it as good angle pass
                n.goodAnglePass=true;
                
            }else{
                
                n.goodAnglePass=false;
            }
            
        }
        
    }
    
    //Test 2. Do other tests here
    
    //remove all non passing angle positions
    supportNodes.erase(std::remove_if(supportNodes.begin(), supportNodes.end(), [&](SupportNode node){return node.goodAnglePass==false;}),supportNodes.end());
    
    //get the closest support positions
    U4DEngine::U4DPoint3n supportSpace1;
    U4DEngine::U4DPoint3n supportSpace2;
    
    //get the support position closest to 45 degree angle
    
    U4DEngine::U4DVector3n supportAngle=rightHandHeading.rotateVectorAboutAngleAndAxis(45.0, upVector);
    
    supportSpace1=analyzeClosestSupportSpaceAlongLine(supportAngle, supportNodes,controllingPlayerPosition);
    
    //get the support position closest to 135 degree angle
    
    supportAngle=rightHandHeading.rotateVectorAboutAngleAndAxis(135.0, upVector);
    
    supportSpace2=analyzeClosestSupportSpaceAlongLine(supportAngle, supportNodes,controllingPlayerPosition);
    
    std::vector<U4DEngine::U4DPoint3n> supportSpace;
    
    supportSpace.push_back(supportSpace1);
    supportSpace.push_back(supportSpace2);
    
    return supportSpace;
}

U4DEngine::U4DPoint3n U11SpaceAnalyzer::computeMovementRelToFieldGoal(U11Team *uTeam, U11Player *uPlayer, float uDistance){
    
    //get the field goal
    U11FieldGoal *fieldGoal=uTeam->getFieldGoal();
    
    U4DEngine::U4DPoint3n playerPosition=uPlayer->getAbsolutePosition().toPoint();
    
    playerPosition.y=0.0;
    
    //get closest point on the field goal to player position
    U4DEngine::U4DPoint3n closestPointOnFieldGoal=fieldGoal->getFieldGoalWidthSegment().closestPointOnSegmentToPoint(playerPosition);
    
    U4DEngine::U4DPoint3n movementSpace=(playerPosition.toVector()+(playerPosition-closestPointOnFieldGoal)*uDistance).toPoint();
    
    return movementSpace;
    
}

std::vector<U11Player*> U11SpaceAnalyzer::analyzeThreateningPlayers(U11Team *uTeam){
    
    U11Ball *ball=uTeam->getSoccerBall();
    
    U11FieldGoal *fieldGoal=uTeam->getFieldGoal();
    
    U4DEngine::U4DVector3n ballLine(fieldGoal->getAbsolutePosition().x-ball->getAbsolutePosition().x,0.0,0.0);
    
    std::vector<U11Player*> threateningPlayersContainer;
    
    U11Team *oppositeTeam=uTeam->getOppositeTeam();
    
    for(auto n:oppositeTeam->getTeammates()){
        
        if (n!=oppositeTeam->getControllingPlayer()) {
            
            U4DEngine::U4DVector3n playerPosition=n->getAbsolutePosition();
            playerPosition.y=0.0;
            
            if (playerPosition.dot(ballLine)>0.0) {
                
                threateningPlayersContainer.push_back(n);
            }
            
        }
        
    }
    
    return threateningPlayersContainer;
    
}

U11Player *U11SpaceAnalyzer::getDefensePlayerClosestToThreatingPlayer(U11Team *uTeam, U11Player *uThreateningPlayer){
    
    //get each support player into a node with its distance to uPosition
    
    //set up the heapsort container
    std::vector<U11Node> heapContainer;
    
    for(auto n:uTeam->getTeammates()){
        
        if (n!=uTeam->getMainDefendingPlayer()) {
            
            U4DEngine::U4DVector3n playerPosition=n->getAbsolutePosition();
            playerPosition.y=0;
            
            U4DEngine::U4DVector3n threateningPlayerPosition=uThreateningPlayer->getAbsolutePosition();
            threateningPlayerPosition.y=0.0;
            
            float distance=(threateningPlayerPosition-playerPosition).magnitude();
            
            //create a node
            U11Node node;
            node.player=n;
            node.data=distance;
            
            heapContainer.push_back(node);
            
        }
        
    }
    
    //sort the players closer to the position
    
    U11HeapSort heapSort;
    heapSort.heapify(heapContainer);
    
    std::vector<U11Player*> sortPlayers;
    
    for(auto n:heapContainer){
        
        sortPlayers.push_back(n.player);
    }
    
    return sortPlayers.at(0);
    
}

std::vector<U11Player*> U11SpaceAnalyzer::analyzeClosestPlayersToBall(U11Team *uTeam){
    
    //get position of the ball
    U4DEngine::U4DVector3n ballPosition=uTeam->getSoccerBall()->getAbsolutePosition();
    
    return analyzePlayersDistanceToPosition(uTeam, ballPosition);
    
}

std::vector<U11Player*> U11SpaceAnalyzer::analyzeClosestPlayersToPosition(U4DEngine::U4DVector3n &uPosition, U11Team *uTeam){
    
    return analyzePlayersDistanceToPosition(uTeam, uPosition);
    
}

std::vector<U11Player*> U11SpaceAnalyzer::analyzeClosestPlayersAlongPassLine(U11Team *uTeam){
    
    U4DEngine::U4DSegment passLine;
    passLine.pointA=uTeam->getSoccerBall()->getAbsolutePosition().toPoint();
    passLine.pointB=uTeam->getSoccerBall()->getVelocity().toPoint()*ballSegmentDirection;
    
    return analyzeClosestPlayersAlongLine(uTeam,passLine);
    
}

std::vector<U11Player*> U11SpaceAnalyzer::analyzeSupportPlayers(U11Team *uTeam){
    
    U4DEngine::U4DVector3n controllingPlayerPosition=uTeam->getControllingPlayer()->getAbsolutePosition();
    
    return analyzePlayersDistanceToPosition(uTeam, controllingPlayerPosition);
    
}

std::vector<U11Player*> U11SpaceAnalyzer::analyzeDefendingPlayer(U11Team *uTeam){
    
    U11Player *oppositeControllingPlayer=uTeam->getOppositeTeam()->getControllingPlayer();
    U4DEngine::U4DVector3n oppositePlayerPosition=oppositeControllingPlayer->getAbsolutePosition();
    
    return analyzePlayersDistanceToPosition(uTeam, oppositePlayerPosition);
    
}

