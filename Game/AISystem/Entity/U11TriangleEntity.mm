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

U11TriangleEntity::U11TriangleEntity(){
    
}

U11TriangleEntity::~U11TriangleEntity(){
    
}

void U11TriangleEntity::buildTriangleEntity(U11Team *uTeam){
    
    triangleNode.player1=uTeam->getControllingPlayer();
    triangleNode.player2=uTeam->getSupportPlayers().at(0);
    triangleNode.player3=uTeam->getSupportPlayers().at(1);
    
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

U4DEngine::U4DPoint3n U11TriangleEntity::getTriangleCentroid(){
    
    //get the distance of opponent players to the triangle entity centroid
    U4DEngine::U4DTriangle triangleGeometry=getTriangleGeometry();
    U4DEngine::U4DPoint3n triangleCentroid=triangleGeometry.getCentroid();
    
    //to have a universal point of measurement set the centroid y position to zero
    triangleCentroid.y=0;
    
    return triangleCentroid;
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
