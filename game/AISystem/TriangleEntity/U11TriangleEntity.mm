//
//  U11TriangleEntity.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/9/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11TriangleEntity.h"
#include "U4DTriangle.h"
#include "U11Player.h"
#include "U11HeapSort.h"
#include "U11Node.h"
#include "U11Team.h"

U11TriangleEntity::U11TriangleEntity(VertexNode uVertexNodeA, VertexNode uVertexNodeB, VertexNode uVertexNodeC):vertexNodeA(uVertexNodeA), vertexNodeB(uVertexNodeB), vertexNodeC(uVertexNodeC){
    
    parent=NULL;
    next=NULL;
    prevSibling=this;
    lastDescendant=this;
    
    triangleGeometry.pointA=uVertexNodeA.optimalPosition;
    triangleGeometry.pointB=uVertexNodeB.optimalPosition;
    triangleGeometry.pointC=uVertexNodeC.optimalPosition;
    
    vertexNodeA.player=uVertexNodeA.player;
    vertexNodeB.player=uVertexNodeB.player;
    vertexNodeC.player=uVertexNodeC.player;
    
    vertexNodeA.optimalPosition=uVertexNodeA.optimalPosition;
    vertexNodeB.optimalPosition=uVertexNodeB.optimalPosition;
    vertexNodeC.optimalPosition=uVertexNodeC.optimalPosition;
    
}

U11TriangleEntity::U11TriangleEntity(){
    
    parent=NULL;
    next=NULL;
    prevSibling=this;
    lastDescendant=this;
    
}

U11TriangleEntity::~U11TriangleEntity(){
    
}

std::vector<U4DEngine::U4DSegment> U11TriangleEntity::getTriangleEntitySegments(){
    
    return triangleGeometry.getSegments();
}

std::vector<U11Player*> U11TriangleEntity::getTriangleEntityPlayers(){
    
    std::vector<U11Player*> players{vertexNodeA.player,vertexNodeB.player,vertexNodeC.player};
    
    return players;
    
}

U4DEngine::U4DVector3n U11TriangleEntity::getTriangleEntityNormal(){
    
    return triangleGeometry.getTriangleNormal();
}

U4DEngine::U4DTriangle U11TriangleEntity::getTriangleEntityGeometry(){
    
    return triangleGeometry;
}

U4DEngine::U4DPoint3n U11TriangleEntity::getTriangleEntityCentroid(){
    
    //get the distance of opponent players to the triangle entity centroid
    U4DEngine::U4DPoint3n triangleCentroid=triangleGeometry.getCentroid();
    
    //to have a universal point of measurement set the centroid y position to zero
    triangleCentroid.y=0;
    
    return triangleCentroid;
}


void U11TriangleEntity::addChild(U11TriangleEntity *uChild){
    
    U11TriangleEntity* lastAddedChild=getFirstChild();
    
    if(lastAddedChild==0){ //add as first child
        
        uChild->parent=this;
        
        uChild->lastDescendant->next=lastDescendant->next;
        
        lastDescendant->next=uChild;
        
        uChild->prevSibling=getLastChild();
        
        if (isLeaf()) {
            
            next=uChild;
            
        }
        
        getFirstChild()->prevSibling=uChild;
        
        changeLastDescendant(uChild->lastDescendant);
        
        
    }else{
        
        uChild->parent=lastAddedChild->parent;
        
        uChild->prevSibling=lastAddedChild->prevSibling;
        
        uChild->lastDescendant->next=lastAddedChild;
        
        if (lastAddedChild->parent->next==lastAddedChild) {
            lastAddedChild->parent->next=uChild;
        }else{
            lastAddedChild->prevSibling->lastDescendant->next=uChild;
        }
        
        lastAddedChild->prevSibling=uChild;
        
    }
    
}

void U11TriangleEntity::removeChild(U11TriangleEntity *uChild){
    
    U11TriangleEntity* sibling = uChild->getNextSibling();
    
    if (sibling)
        sibling->prevSibling = uChild->prevSibling;
    else
        getFirstChild()->prevSibling = uChild->prevSibling;
    
    if (lastDescendant == uChild->lastDescendant)
        changeLastDescendant(uChild->prevInPreOrderTraversal());
    
    if (next == uChild)	// deleting first child?
        next = uChild->lastDescendant->next;
    else
        uChild->prevSibling->lastDescendant->next = uChild->lastDescendant->next;
}

U11TriangleEntity *U11TriangleEntity::prevInPreOrderTraversal(){
    
    U11TriangleEntity* prev = 0;
    if (parent)
    {
        if (parent->next == this)
            prev = parent;
        else
            prev = prevSibling->lastDescendant;
    }
    return prev;
}

U11TriangleEntity *U11TriangleEntity::nextInPreOrderTraversal(){
    return next;
}

U11TriangleEntity *U11TriangleEntity::getFirstChild(){
    
    U11TriangleEntity* child=NULL;
    if(next && (next->parent==this)){
        child=next;
    }
    
    return child;
}

U11TriangleEntity *U11TriangleEntity::getLastChild(){
    
    U11TriangleEntity *child=getFirstChild();
    
    if(child){
        child=child->prevSibling;
    }
    
    return child;
}

U11TriangleEntity *U11TriangleEntity::getNextSibling(){
    
    U11TriangleEntity* sibling = lastDescendant->next;
    if (sibling && (sibling->parent != parent))
        sibling = 0;
    return sibling;
}


U11TriangleEntity *U11TriangleEntity::getPrevSibling(){
    U11TriangleEntity* sibling = 0;
    if (parent && (parent->next != this))
        sibling =prevSibling;
    return sibling;
}

void U11TriangleEntity::changeLastDescendant(U11TriangleEntity *uNewLastDescendant){
    
    U11TriangleEntity *oldLast=lastDescendant;
    U11TriangleEntity *ancestor=this;
    
    do{
        ancestor->lastDescendant=uNewLastDescendant;
        ancestor=ancestor->parent;
    }while (ancestor && (ancestor->lastDescendant==oldLast));
    
}

bool U11TriangleEntity::isRoot(){
    
    bool value=false;
    
    if (parent==0) {
        
        value=true;
        
    }
    
    return value;
}

bool U11TriangleEntity::isLeaf(){
    
    return (lastDescendant==this);
    
}


/*
void U11TriangleEntity::buildTriangleEntity(U11Team *uTeam){
 
    triangleNode.player1=uTeam->getControllingPlayer();
    triangleNode.player2=uTeam->analyzeSupportPlayers().at(0);
    triangleNode.player3=uTeam->analyzeSupportPlayers().at(1);
 
}

TriangleNode &U11TriangleEntity::getTriangleNode(){
 
    return triangleNode;
 
}


U4DEngine::U4DTriangle U11TriangleEntity::getTriangleGeometry(){
 
    //get the nodes

    U11Player *player1=triangleNode.player1;
    U11Player *player2=triangleNode.player2;
    U11Player *player3=triangleNode.player3;
 
    U4DEngine::U4DPoint3n pos1=player1->getAbsolutePosition().toPoint();
    U4DEngine::U4DPoint3n pos2=player2->getAbsolutePosition().toPoint();
    U4DEngine::U4DPoint3n pos3=player3->getAbsolutePosition().toPoint();
    
    pos1.y=0.0;
    pos2.y=0.0;
    pos3.y=0.0;
    
    U4DEngine::U4DTriangle triangle(pos1,pos2,pos3);
    
    return triangle;
    
}



std::vector<U11Player*> U11TriangleEntity::getThreatPlayersInsideTriangle(){
    
    //get opposite team
    U11Team *oppositeTeam=triangleNode.player1->getTeam()->getOppositeTeam();
    
    //for each opposite team member compute if they are within the triangle
    std::vector<U11Player*> threatPlayers;
    
    for(auto n:oppositeTeam->getTeammates()){
        
        U4DEngine::U4DPoint3n playerPosition=n->getAbsolutePosition().toPoint();
        playerPosition.y=0.0;
        
        if(getTriangleGeometry().isPointOnTriangle(playerPosition)){
            
            threatPlayers.push_back(n);
        }
        
    }
    
    if (threatPlayers.size()>1) {
        isTriangleEntitySafe=false;
    }else{
        isTriangleEntitySafe=true;
    }
    
    return threatPlayers;
    
}


bool U11TriangleEntity::getIsTriangleEntitySafe(){
    
    return isTriangleEntitySafe;

}
 */
