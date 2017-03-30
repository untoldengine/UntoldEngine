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

U11SpaceAnalyzer::U11SpaceAnalyzer(){
    
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

U4DEngine::U4DPoint3n U11SpaceAnalyzer::analyzeClosestSupportSpaceToPlayer(U11Player *uSupportPlayer, std::vector<U4DEngine::U4DPoint3n> &uSupportPoints){
    
    //set up the heapsort container
    std::vector<U11Node> heapContainer;
    
    //get support player distance to support node point
    for(auto n:uSupportPoints){
        
        U4DEngine::U4DVector3n playerPosition=uSupportPlayer->getAbsolutePosition();
        
        float distance=(n.toVector()-playerPosition).magnitude();
        
        //create a node
        U11Node node;
        node.player=uSupportPlayer;
        node.supportPoint=n;
        node.data=distance;
        
        heapContainer.push_back(node);
        
    }
    
    //sort the position closer to the support player
    U11HeapSort heapSort;
    
    heapSort.heapify(heapContainer);
    
    //return closest support point
   
    return heapContainer.at(0).supportPoint;
    
}

std::vector<U4DEngine::U4DPoint3n> U11SpaceAnalyzer::computeOptimalSupportSpace(U11Team *uTeam){
    
    //compute the nodes position
    
    //get the controlling player heading
    U11Player *controllingPlayer=uTeam->getControllingPlayer();
    U4DEngine::U4DVector3n playerHeading=controllingPlayer->getPlayerHeading();
    
    playerHeading.normalize();
    
    //get the right hand heading of the player
    U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
    
    U4DEngine::U4DVector3n rightHandHeading=playerHeading.cross(upVector);
    
    for(int i=0;i<=maximumSupportPoints;i++){
        
        U4DEngine::U4DVector3n position=rightHandHeading.rotateVectorAboutAngleAndAxis(i*supportPointsSeparation, upVector);
        
        SupportNode supportNode;
        supportNode.point=position.toPoint()*supportMaximumDistanceToPlayer+controllingPlayer->getAbsolutePosition().toPoint();
        supportNode.point.y=0.0;
        
        supportNodes.push_back(supportNode);
        
    }
    
    //score each position
    
    //get opposite players
    U11Team *oppositeTeam=uTeam->getOppositeTeam();
    U4DEngine::U4DVector3n controllingPlayerPosition=controllingPlayer->getAbsolutePosition();
    
    //compute closest players to controlling player
    std::vector<U11Player*> oppositePlayers=analyzePlayersDistanceToPosition(oppositeTeam, controllingPlayerPosition);
    
    if (oppositePlayers.size()>4) {
        oppositePlayers.resize(4);
    }
    
    //Test 1. check if it passing angle does not intersept an opponent
    for(auto n:supportNodes){
        
        for(auto m:oppositePlayers){
            
            //get the segment between the support space and controlling player
            U4DEngine::U4DPoint3n pointA=controllingPlayerPosition.toPoint();
            U4DEngine::U4DPoint3n pointB=n.point;
            U4DEngine::U4DSegment passingAngle(pointA,pointB);
            
            if (!m->getPlayerSpaceBox().intersectionWithSegment(passingAngle)) {
                
                //set it as good angle pass
                n.goodAnglePass=true;
                
            }else{
                n.goodAnglePass=false;
            }
            
        }
        
    }
    
    //Test 2. Do other tests here
    
    //remove all non passing angle positions
    supportNodes.erase(std::remove_if(supportNodes.begin(), supportNodes.end(), [&](SupportNode node){return node.goodAnglePass==true;}),supportNodes.end());
    
    std::vector<U4DEngine::U4DPoint3n> supportPointsContainer;
    
    for(auto n:supportNodes){
        
        supportPointsContainer.push_back(n.point);
        
    }
    
    //get closest support points to support players
    U11Player *supportPlayer1=uTeam->getSupportPlayer1();
    U11Player *supportPlayer2=uTeam->getSupportPlayer2();
    
    U4DEngine::U4DPoint3n supportSpace1=analyzeClosestSupportSpaceToPlayer(supportPlayer1, supportPointsContainer);
    U4DEngine::U4DPoint3n supportSpace2=analyzeClosestSupportSpaceToPlayer(supportPlayer2, supportPointsContainer);
    
    std::vector<U4DEngine::U4DPoint3n> supportSpace;
    supportSpace.push_back(supportSpace1);
    supportSpace.push_back(supportSpace2);
    
    return supportSpace;
}
