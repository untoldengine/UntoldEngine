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

std::vector<U11Player*> U11SpaceAnalyzer::getPlayersClosestToPosition(U11Team *uTeam, U4DEngine::U4DVector3n &uPosition){
    
    //get each support player into a node with its distance to uPosition
    
    uPosition.y=0;
    
    //set up the heapsort container
    std::vector<U11Node> heapContainer;
    
    for(auto n:uTeam->getTeammates()){
            
            U4DEngine::U4DVector3n playerPosition=n->getCurrentPosition();
            
            float distance=(uPosition-playerPosition).magnitude();
            
            //create a node
            U11Node node;
            node.player=n;
            node.data=distance;
            
            heapContainer.push_back(node);

        
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

std::vector<U11Player*> U11SpaceAnalyzer::getPlayersClosestToPosition(U4DEngine::U4DVector3n &uPosition, std::vector<U11Player*> uPlayers){
    
    //get each support player into a node with its distance to uPosition
    
    uPosition.y=0;
    
    //set up the heapsort container
    std::vector<U11Node> heapContainer;
    
    for(auto n:uPlayers){
        
        U4DEngine::U4DVector3n playerPosition=n->getCurrentPosition();
        
        float distance=(uPosition-playerPosition).magnitude();
        
        //create a node
        U11Node node;
        node.player=n;
        node.data=distance;
        
        heapContainer.push_back(node);
        
        
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

std::vector<U11Player*> U11SpaceAnalyzer::getClosestPlayersToPlayer(U11Team *uTeam, U11Player *uPlayer){
    
    //set up the heapsort container
    std::vector<U11Node> heapContainer;
    
    U4DEngine::U4DVector3n uPosition=uPlayer->getCurrentPosition();
    
    for(auto n:uTeam->getTeammates()){
        
        if (n!=uPlayer) {
            
            U4DEngine::U4DVector3n playerPosition=n->getCurrentPosition();
            
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


std::vector<U11Player*> U11SpaceAnalyzer::getPlayersClosestToLine(U11Team *uTeam, U4DEngine::U4DSegment &uLine){
    
    //get each support player into a node with its distance to uPosition
    
    uLine.pointA.y=0.0;
    uLine.pointB.y=0.0;
    
    //set up the heapsort container
    std::vector<U11Node> heapContainer;
    
    for(auto n:uTeam->getTeammates()){
        
            U4DEngine::U4DPoint3n playerPosition=n->getCurrentPosition().toPoint();
            
            float distance=uLine.sqDistancePointSegment(playerPosition);
            
            //create a node
            U11Node node;
            node.player=n;
            node.data=distance;
            
            heapContainer.push_back(node);
        
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

std::vector<U11Player*> U11SpaceAnalyzer::getPlayersClosestToLine(std::vector<U11Player*> uPlayers, U4DEngine::U4DSegment &uLine){
    
    //get each support player into a node with its distance to uPosition
    
    uLine.pointA.y=0.0;
    uLine.pointB.y=0.0;
    
    //set up the heapsort container
    std::vector<U11Node> heapContainer;
    
    for(auto n:uPlayers){
        
        U4DEngine::U4DPoint3n playerPosition=n->getCurrentPosition().toPoint();
        
        float distance=uLine.sqDistancePointSegment(playerPosition);
        
        //create a node
        U11Node node;
        node.player=n;
        node.data=distance;
        
        heapContainer.push_back(node);
        
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


std::vector<U4DEngine::U4DPoint3n> U11SpaceAnalyzer::computeOptimalSupportSpace(U11Team *uTeam){
    
    //compute the nodes position
    
    //get the controlling player heading
    U11Player *controllingPlayer=uTeam->getControllingPlayer();
    U4DEngine::U4DVector3n playerHeading=controllingPlayer->getPlayerHeading();
    U4DEngine::U4DVector3n controllingPlayerPosition=controllingPlayer->getCurrentPosition();
    
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
    std::vector<U11Player*> oppositePlayers=getPlayersClosestToPosition(oppositeTeam, controllingPlayerPosition);
    
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
    
    supportSpace1=getClosestSupportSpaceAlongLine(supportAngle, supportNodes,controllingPlayerPosition);
    
    //get the support position closest to 135 degree angle
    
    supportAngle=rightHandHeading.rotateVectorAboutAngleAndAxis(135.0, upVector);
    
    supportSpace2=getClosestSupportSpaceAlongLine(supportAngle, supportNodes,controllingPlayerPosition);
    
    std::vector<U4DEngine::U4DPoint3n> supportSpace;
    
    supportSpace.push_back(supportSpace1);
    supportSpace.push_back(supportSpace2);
    
    return supportSpace;
}

U4DEngine::U4DPoint3n U11SpaceAnalyzer::getClosestSupportSpaceAlongLine(U4DEngine::U4DVector3n &uLine, std::vector<SupportNode> &uSupportNodes, U4DEngine::U4DVector3n &uControllingPlayerPosition){
    
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


U4DEngine::U4DVector3n U11SpaceAnalyzer::computeOptimalDribblingVector(U11Team *uTeam){
    
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
    
    for(int i=0;i<maximumDribblingSpace;i++){
        
        U4DEngine::U4DVector3n position=rightHandHeading.rotateVectorAboutAngleAndAxis(i*dribblingSpaceSeparation, upVector);
        
        DribblingNode dribblingNode;
        dribblingNode.position=position.toPoint()*dribblingMinimumDistanceToPlayer+controllingPlayerPosition.toPoint();
        
        dribblingNodes.push_back(dribblingNode);
        
    }
    
    //score each position
    
    //get opposite players
    U11Team *oppositeTeam=uTeam->getOppositeTeam();
    
    //compute closest players to controlling player
    U11Player* oppositePlayer=getPlayersClosestToPosition(oppositeTeam, controllingPlayerPosition).at(0);
    
    //assign closest player
    controllingPlayer->setThreateningPlayer(oppositePlayer);
    
    //Test 1. check if it dribbling angle does not intersept an opponent and if it lands outside the playing field
    for(auto &n:dribblingNodes){
        
        //get the segment between the support space and controlling player
        U4DEngine::U4DPoint3n pointA=controllingPlayerPosition.toPoint();
        U4DEngine::U4DPoint3n pointB=n.position;
        U4DEngine::U4DSegment dribblingSpace(pointB,pointA);
        
        
            if (!oppositePlayer->getUpdatedPlayerSpaceBox().intersectionWithSegment(dribblingSpace)) {
                
                //set it as good angle pass
                n.safeDribblingSpace=true;
                
            }else{
                
                n.safeDribblingSpace=false;
            }
        
    }
    
    
    //Test 2. Do other tests here
    
    //remove all non dribbling angle positions
    dribblingNodes.erase(std::remove_if(dribblingNodes.begin(), dribblingNodes.end(), [&](DribblingNode node){return node.safeDribblingSpace==false;}),dribblingNodes.end());
    
    
    if (dribblingNodes.size()!=0) {
      
    //get the dribbling space closest to the goal
    
    //get the closest point on the opposite field goal relative to dribbling player
    
    //get the field goal
    U11FieldGoal *fieldGoal=uTeam->getOppositeTeam()->getFieldGoal();
    
    U4DEngine::U4DPoint3n playerPosition=controllingPlayerPosition.toPoint();
    
    U4DEngine::U4DPoint3n closestPointOnFieldGoal=fieldGoal->getFieldGoalWidthSegment().closestPointOnSegmentToPoint(playerPosition);
    
    U4DEngine::U4DVector3n playerToGoal=playerPosition-closestPointOnFieldGoal;
    
    return getClosestDribblingVectorTowardsGoal(dribblingNodes, playerToGoal, controllingPlayerPosition);
        
    }else{
        return U4DEngine::U4DVector3n(-1.0,0.0,0.0);
    }
    
}

U4DEngine::U4DVector3n U11SpaceAnalyzer::getClosestDribblingVectorTowardsGoal(std::vector<DribblingNode> &uDribblingNodes, U4DEngine::U4DVector3n &uPlayerToGoalVector, U4DEngine::U4DVector3n &uControllingPlayerPosition){
    
    uPlayerToGoalVector.normalize();
    
    //set up the heapsort container
    std::vector<U11Node> heapContainer;
    
    //get all the dribbling points
    for(auto n:uDribblingNodes){
        
        //create a segment
        U4DEngine::U4DPoint3n pointA=n.position;
        U4DEngine::U4DPoint3n player=uControllingPlayerPosition.toPoint();
        
        U4DEngine::U4DVector3n playerToDribbleVector=player-pointA;
        
        playerToDribbleVector.normalize();
        
        float dotProduct=playerToDribbleVector.dot(uPlayerToGoalVector);
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
    U4DEngine::U4DVector3n optimalDribblingSpace=heapContainer.at(0).supportPoint.toVector()-uControllingPlayerPosition;
    
    return optimalDribblingSpace;
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


U11Player *U11SpaceAnalyzer::getDefensePlayerClosestToThreatPlayer(U11Team *uTeam, U11Player *uThreatPlayer){
    
    //get each support player into a node with its distance to uPosition
    
    //set up the heapsort container
    std::vector<U11Node> heapContainer;
    
    for(auto n:uTeam->getTeammates()){
        
        if (n!=uTeam->getMainDefendingPlayer()) {
            
            U4DEngine::U4DVector3n playerPosition=n->getCurrentPosition();
            
            U4DEngine::U4DVector3n threatPlayerPosition=uThreatPlayer->getCurrentPosition();
            
            float distance=(threatPlayerPosition-playerPosition).magnitude();
            
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

std::vector<U11Player*> U11SpaceAnalyzer::getClosestPlayersToBall(U11Team *uTeam){
    
    //get position of the ball
    U4DEngine::U4DVector3n ballPosition=uTeam->getSoccerBall()->getAbsolutePosition();
    
    return getPlayersClosestToPosition(uTeam, ballPosition);
    
}

std::vector<U11Player*> U11SpaceAnalyzer::analyzeClosestPlayersToPosition(U4DEngine::U4DVector3n &uPosition, U11Team *uTeam){
    
    return getPlayersClosestToPosition(uTeam, uPosition);
    
}


std::vector<U11Player*> U11SpaceAnalyzer::getClosestSupportPlayers(U11Team *uTeam){
    
    U4DEngine::U4DVector3n controllingPlayerPosition=uTeam->getControllingPlayer()->getAbsolutePosition();
    
    return getPlayersClosestToPosition(uTeam, controllingPlayerPosition);
    
}

std::vector<U11Player*> U11SpaceAnalyzer::getClosestDefendingPlayers(U11Team *uTeam){
    
    U11Player *oppositeControllingPlayer=uTeam->getOppositeTeam()->getControllingPlayer();
    U4DEngine::U4DVector3n oppositePlayerPosition=oppositeControllingPlayer->getAbsolutePosition();
    
    return getPlayersClosestToPosition(uTeam, oppositePlayerPosition);
    
}

int U11SpaceAnalyzer::getNumberOfThreateningPlayers(U11Team *uTeam, U11Player *uPlayer){
    
    U4DEngine::U4DVector3n position=uPlayer->getAbsolutePosition();
    
    std::vector<U11Player*> threateningPlayers=analyzeClosestPlayersToPosition(position, uTeam->getOppositeTeam());
    
    if (threateningPlayers.size()>3) {
        
        threateningPlayers.resize(3);
        
    }
    
    int numberOfThreateningPlayers=0;
    
    for (auto n:threateningPlayers) {
        
        if((n->getAbsolutePosition()-uPlayer->getAbsolutePosition()).magnitude()<threateningDistanceToPlayer){
            
            numberOfThreateningPlayers++;
        }
    }
    
    return numberOfThreateningPlayers;
}

bool U11SpaceAnalyzer::analyzeIfPlayerIsCloserToGoalThanMainPlayer(U11Team *uTeam, U11Player *uPlayer){
 
    U11FieldGoal *fieldGoal=uTeam->getOppositeTeam()->getFieldGoal();
    
    U11Player *mainPlayer=uTeam->getControllingPlayer();
    
    U4DEngine::U4DVector3n fieldGoalPosition=fieldGoal->getAbsolutePosition();
    
    int fieldGoalToPlayerDistance=(fieldGoalPosition-mainPlayer->getAbsolutePosition()).magnitude();
    
    int fieldGoalToSupportDistance=(fieldGoalPosition-uPlayer->getAbsolutePosition()).magnitude();
    
    if (fieldGoalToSupportDistance<fieldGoalToPlayerDistance) {
        
        return true;
    
    }
    
    return false;
}

bool U11SpaceAnalyzer::ballWillBeIntercepted(U11Team *uTeam, U11Player *uControllingPlayer, U11Player* uReceivingPlayer){
    
    U4DEngine::U4DPoint3n startingPass=uControllingPlayer->getCurrentPosition().toPoint();
    U4DEngine::U4DPoint3n endingPass=uReceivingPlayer->getCurrentPosition().toPoint();
    
    U4DEngine::U4DSegment segment(startingPass, endingPass);
    
    U11Player *threatPlayer=getPlayersClosestToLine(uTeam->getOppositeTeam(), segment).at(0);
    
    U4DEngine::U4DPoint3n threatPoint=threatPlayer->getCurrentPosition().toPoint();
    
    //getclosest point between segment and threat point
    U4DEngine::U4DPoint3n closestInterceptionPoint=segment.closestPointOnSegmentToPoint(threatPoint);
    
    //get the distance to intercept
    float distanceToIntercept=(closestInterceptionPoint-threatPoint).magnitude();
    
    float timeToIntercept=distanceToIntercept/maximumInterceptionSpeed;
    
    //distance between pass
    
    float passDistance=(startingPass-endingPass).magnitude();
    
    //get time to reach
    float timeToReachReceiver=passDistance/maximumBallSpeed;
    
    if (timeToReachReceiver>timeToIntercept) {
        return true;
    }

    return false;
    
}

float U11SpaceAnalyzer::passSpeedToAvoidInterception(U11Team *uTeam, U11Player *uControllingPlayer, U11Player* uReceivingPlayer){
    
}

std::vector<U11Player*> U11SpaceAnalyzer::getClosestInterceptingPlayers(U11Team *uTeam){
    
    //1. get the ball future position
    //get controlling player position
    
    U11Player *oppositeControllingPlayer=uTeam->getOppositeTeam()->getControllingPlayer();
    
    U4DEngine::U4DPoint3n startingPass=oppositeControllingPlayer->getAbsolutePosition().toPoint();
    
    //get ball heading
    U4DEngine::U4DVector3n ballVelocity=uTeam->getSoccerBall()->getVelocity();
    
    ballVelocity.normalize();
    
    U4DEngine::U4DPoint3n ballDirection=ballVelocity.toPoint();
    
    //get ball kick speed
    float t=oppositeControllingPlayer->getBallKickSpeed();
    
    //get the destination point
    U4DEngine::U4DPoint3n endingPass=startingPass+ballDirection*t;
    
    U4DEngine::U4DSegment segment(startingPass, endingPass);
    
    std::vector<U11Player*> interceptingPlayers=getPlayersClosestToLine(uTeam, segment);
    
    return interceptingPlayers;
    
}

