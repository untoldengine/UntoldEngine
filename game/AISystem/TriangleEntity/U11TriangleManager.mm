//
//  U11TriangleManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/18/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11TriangleManager.h"
#include "U11Team.h"
#include "U11Player.h"
#include "U11SpaceAnalyzer.h"
#include "UserCommonProtocols.h"
#include "U11TriangleEntity.h"
#include "U4DPlane.h"
#include "U4DNumerical.h"

U11TriangleManager::U11TriangleManager():triangleEntityIndex(0){
    
    triangleEntityRoot=new U11TriangleEntity();
    
}

U11TriangleManager::~U11TriangleManager(){
    
    delete triangleEntityRoot;
}

void U11TriangleManager::initTriangleEntitiesComputation(U11Team *uTeam){
    
    buildInitialTriangleEntity(uTeam);
    
    buildTriangleEntities(uTeam);
    
}

void U11TriangleManager::buildInitialTriangleEntity(U11Team *uTeam){
    
    //for all players clear the processed for triangle node flag
    
    for(auto n:uTeam->getTeammates()){
        
        n->setProcessedForTriangleNode(false);
        
    }
    
    //get the controlling player
    U11Player *controllingPlayer=uTeam->getControllingPlayer();
    
    U4DEngine::U4DVector3n controllerPosition=controllingPlayer->getCurrentPosition();
    
    //get closest teammate to controlling player
    U11SpaceAnalyzer spaceAnalyzer;
    
    std::vector<U11Player *> closestPlayersToControllingPlayer=spaceAnalyzer.getClosestPlayersToPlayer(uTeam, controllingPlayer);
    
    U11Player *supportPlayer=closestPlayersToControllingPlayer.at(0);
    
    U4DEngine::U4DVector3n supportPosition=supportPlayer->getCurrentPosition();
    
    //make sure the support Player is not to close to the main controlling player
    float edgeDistance=(supportPosition-controllerPosition).magnitude();
    
    //get the third closest player relative to the segment
    U4DEngine::U4DVector3n triangleEdgeVector=supportPosition-controllerPosition;
    
    U4DEngine::U4DVector3n triangleEdgeNormalizeVector=triangleEdgeVector;
    
    triangleEdgeNormalizeVector.normalize();
    
    if (edgeDistance<triangleEntityDistance) {
        
        supportPosition=controllerPosition+(triangleEdgeNormalizeVector)*triangleEntityDistance;
        
    }
    
    U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
    
    U4DEngine::U4DVector3n leftHandNormalVector=triangleEdgeNormalizeVector.cross(upVector);
    U4DEngine::U4DVector3n rightHandNormalVector=upVector.cross(triangleEdgeNormalizeVector);
    
    U4DEngine::U4DPoint3n midPoint=(controllerPosition+(triangleEdgeVector)*0.5).toPoint();
    
    //get the endpoint for the perpendicular endpoint
    U4DEngine::U4DPoint3n leftHandEndPoint=midPoint+((leftHandNormalVector)*triangleEntityDistance).toPoint();
    U4DEngine::U4DPoint3n rightHandEndPoint=midPoint+((rightHandNormalVector)*triangleEntityDistance).toPoint();
    
    //create the segments
    U4DEngine::U4DSegment leftHandSegment(midPoint,leftHandEndPoint);
    
    U4DEngine::U4DSegment rightHandSegment(midPoint,rightHandEndPoint);
    
    //get all the players inside the plane
    
    U4DEngine::U4DPoint3n planePoint=controllerPosition.toPoint();
    
    std::vector<U11Player*> playersInsidePlane=getPlayersInsidePlane(uTeam, leftHandNormalVector, planePoint);
    
    U4DEngine::U4DPoint3n optimalPosition=leftHandSegment.pointB;
    
    U4DEngine::U4DSegment segmentToTest=leftHandSegment;
    
    if (playersInsidePlane.size()==0) {
        
        playersInsidePlane=getPlayersInsidePlane(uTeam, rightHandNormalVector, planePoint);
        
        optimalPosition=rightHandSegment.pointB;
        
        segmentToTest=rightHandSegment;
    }
    
    
    //get closest player to segment
    
    std::vector<U11Player*> closestPlayersToSegment=spaceAnalyzer.getPlayersClosestToLine(playersInsidePlane, segmentToTest);
    
    VertexNode nodeA;
    nodeA.player=controllingPlayer;
    nodeA.optimalPosition=controllerPosition.toPoint();
    
    VertexNode nodeB;
    nodeB.player=supportPlayer;
    nodeB.optimalPosition=supportPosition.toPoint();
    
    VertexNode nodeC;
    nodeC.player=closestPlayersToSegment.at(0);
    nodeC.optimalPosition=optimalPosition;
    
    //build the triangle entity
    U11TriangleEntity *triangleNodeEntity= new U11TriangleEntity (nodeA, nodeB, nodeC);
    
    triangleEntityRoot->addChild(triangleNodeEntity);
    
    //get the centroid of the triangle
    U4DEngine::U4DPoint3n triangleCentroid=triangleNodeEntity->getTriangleEntityCentroid();
    
    //get the segments of the triangle
    
    SegmentNode segmentAB;
    segmentAB.segment=triangleNodeEntity->getTriangleEntitySegments().at(0);
    segmentAB.nodeA=nodeA;
    segmentAB.nodeB=nodeB;
    segmentAB.centroid=triangleCentroid;
    segmentAB.segmentParent=triangleNodeEntity;
    
    SegmentNode segmentBC;
    segmentBC.segment=triangleNodeEntity->getTriangleEntitySegments().at(1);
    segmentBC.nodeA=nodeB;
    segmentBC.nodeB=nodeC;
    segmentBC.centroid=triangleCentroid;
    segmentBC.segmentParent=triangleNodeEntity;
    
    SegmentNode segmentCA;
    segmentCA.segment=triangleNodeEntity->getTriangleEntitySegments().at(2);
    segmentCA.nodeA=nodeC;
    segmentCA.nodeB=nodeA;
    segmentCA.centroid=triangleCentroid;
    segmentCA.segmentParent=triangleNodeEntity;
    
    //push the segments into the queue
    segmentQueue.push(segmentAB);
    segmentQueue.push(segmentBC);
    segmentQueue.push(segmentCA);
    
    //set players that have been processed
    controllingPlayer->setProcessedForTriangleNode(true);
    supportPlayer->setProcessedForTriangleNode(true);
    closestPlayersToSegment.at(0)->setProcessedForTriangleNode(true);
    
    //add each node into the vertex container
    vertexNodeContainer.push_back(nodeA);
    vertexNodeContainer.push_back(nodeB);
    vertexNodeContainer.push_back(nodeC);
    
}

void U11TriangleManager::buildTriangleEntities(U11Team *uTeam){
    
    U11SpaceAnalyzer spaceAnalyzer;
    
    while (!segmentQueue.empty()) {
        
        //get segment
        SegmentNode segmentNode=segmentQueue.front();
        
        U4DEngine::U4DSegment segment=segmentNode.segment;
        
        //create a vector
        U4DEngine::U4DVector3n segmentVector=segment.pointA-segment.pointB;
        
        //get closest point of the centroid to the segment
        U4DEngine::U4DPoint3n closestPointToSegment=segment.closestPointOnSegmentToPoint(segmentNode.centroid);
        
        //get the vector from the centroid to the point closest to segment. This represents the normal to the segment
        U4DEngine::U4DVector3n normal=segmentNode.centroid-closestPointToSegment;

        normal.normalize();
        
        //get all the players inside the plane
        std::vector<U11Player*> playersInsidePlane=getPlayersInsidePlane(uTeam, normal, segment.pointA);
        
        //if there are players inside the plane, then compute the midpoint and the endpoint
        if (playersInsidePlane.size()>0) {
            
            U4DEngine::U4DPoint3n midPoint=(segment.pointA.toVector()+(segmentVector)*0.5).toPoint();
            
            U4DEngine::U4DPoint3n endPoint=midPoint+((normal)*triangleEntityDistance).toPoint();
            
            U4DEngine::U4DSegment normalSegment(midPoint,endPoint);
            
            //get closest player to segment
            
            std::vector<U11Player*> closestPlayersToSegment=spaceAnalyzer.getPlayersClosestToLine(playersInsidePlane, normalSegment);
            
            //add triangle to container
            VertexNode nodeA;
            nodeA.player=segmentNode.nodeA.player;
            nodeA.optimalPosition=segmentNode.nodeA.optimalPosition;
            
            VertexNode nodeB;
            nodeB.player=segmentNode.nodeB.player;
            nodeB.optimalPosition=segmentNode.nodeB.optimalPosition;
            
            VertexNode nodeC;
            nodeC.player=closestPlayersToSegment.at(0);
            nodeC.optimalPosition=endPoint;
            
            //build the triangle entity
            U11TriangleEntity *triangleNodeEntity=new U11TriangleEntity(nodeA, nodeB, nodeC);
            
            segmentNode.segmentParent->addChild(triangleNodeEntity);
            
            //get the centroid of the triangle
            U4DEngine::U4DPoint3n triangleCentroid=triangleNodeEntity->getTriangleEntityCentroid();
   
            
            //create segments to add to the queue
            SegmentNode segmentBC;
            segmentBC.segment=triangleNodeEntity->getTriangleEntitySegments().at(1);
            segmentBC.nodeA=nodeB;
            segmentBC.nodeB=nodeC;
            segmentBC.centroid=triangleCentroid;
            segmentBC.segmentParent=triangleNodeEntity;
            
            SegmentNode segmentCA;
            segmentCA.segment=triangleNodeEntity->getTriangleEntitySegments().at(2);
            segmentCA.nodeA=nodeC;
            segmentCA.nodeB=nodeA;
            segmentCA.centroid=triangleCentroid;
            segmentCA.segmentParent=triangleNodeEntity;
            
            //push the segments into the queue
            segmentQueue.push(segmentBC);
            segmentQueue.push(segmentCA);
            
            closestPlayersToSegment.at(0)->setProcessedForTriangleNode(true);
            
            //add to vertex container
            vertexNodeContainer.push_back(nodeC);
        }
        
        segmentQueue.pop();
    }
    
}

std::vector<VertexNode> U11TriangleManager::getVertexNodeContainer(){
    
    return vertexNodeContainer;
}

std::vector<U11Player*> U11TriangleManager::getPlayersInsidePlane(U11Team *uTeam, U4DEngine::U4DVector3n &uNormal, U4DEngine::U4DPoint3n &uPlanePoint){
    
    U4DEngine::U4DNumerical numerical;
    
    std::vector<U11Player*> playersInsidePlane;
    
    //create plane
    U4DEngine::U4DPlane plane(uNormal, uPlanePoint);
    
    for(auto n:uTeam->getTeammates()){
        
        if (n->getProcessedForTriangleNode()==false) {
            
            U4DEngine::U4DPoint3n position=n->getCurrentPosition().toPoint();
            
            float distanceToPlane=plane.magnitudeOfPointToPlane(position);
            
            if (numerical.areEqualAbs(distanceToPlane, 0.0, U4DEngine::zeroEpsilon)) {
                
                distanceToPlane=0.0;
                
            }
            
            if (distanceToPlane>0.0) {
                
                playersInsidePlane.push_back(n);
                
            }
            
        }
        
    }
    
    return playersInsidePlane;
    
}

void U11TriangleManager::removeAllTriangleNodes(){
    
    U11TriangleEntity *lastNode=triangleEntityRoot->lastDescendant;
    U11TriangleEntity *parentNode=lastNode->parent;
    
    while (triangleEntityRoot->next !=nullptr) {
        
        if (lastNode->isRoot()) {
            
            lastNode=nullptr;
            
            delete lastNode;
            
        }else{
            
            parentNode->removeChild(lastNode);
            
            delete lastNode;
            
            lastNode=triangleEntityRoot->lastDescendant;
            
            parentNode=lastNode->parent;
            
        }
        
    }
    
}

U11TriangleEntity *U11TriangleManager::getTriangleEntityRoot(){
    
    return triangleEntityRoot;
}

void U11TriangleManager::clearContainers(){
    
    removeAllTriangleNodes();
    vertexNodeContainer.clear();
    
}
