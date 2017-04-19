//
//  U11Formation.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/15/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11Formation.h"
#include "U11Field.h"
#include "U4DAABB.h"
#include "U4DSegment.h"

U11Formation::U11Formation(){}

U11Formation::~U11Formation(){}


std::vector<U4DEngine::U4DAABB> U11Formation::partitionAABBAlongDirection(U4DEngine::U4DAABB &uAABB,U4DEngine::U4DVector3n &uDirection, int uSpaces){
    
    //get the aabb minpoint
    U4DEngine::U4DPoint3n aabbMinPoint=uAABB.getMinPoint();
    
    //get the halfwidth
    U4DEngine::U4DVector3n halfwidth=uAABB.getHalfWidth();
    halfwidth=halfwidth*2.0;
    
    U4DEngine::U4DVector3n axis(halfwidth.x*uDirection.x,halfwidth.y*uDirection.y,halfwidth.z*uDirection.z);
    
    U4DEngine::U4DPoint3n aabbEndPoint(aabbMinPoint.x+axis.x,aabbMinPoint.y+axis.y,aabbMinPoint.z+axis.z);
    
    U4DEngine::U4DSegment aabbSegment(aabbMinPoint,aabbEndPoint);
    
    
    //translate the segment to zero coordinates
    U4DEngine::U4DVector3n offset=aabbSegment.pointA.toVector();
    
    U4DEngine::U4DSegment axisOffset;
    axisOffset.pointA=(offset.toPoint()-aabbSegment.pointA).toPoint();
    axisOffset.pointB=(offset.toPoint()-aabbSegment.pointB).toPoint();
    
    //get the parametric equation of the segment
    
    U4DEngine::U4DVector3n direction=axisOffset.pointA-axisOffset.pointB;
    
    U4DEngine::U4DVector3n axisParametricVector=axisOffset.pointA.toVector()+direction*(1.0/uSpaces);
    
    //get the partition points
    
    std::vector<U4DEngine::U4DPoint3n> aabbPoints;
    
    for (int i=0; i<=uSpaces; i++) {
        
        U4DEngine::U4DPoint3n point=(axisParametricVector*i).toPoint()+offset.toPoint();
        
        aabbPoints.push_back(point);
        
    }
    
    //divide the halfwidth depending on the direction
    
    direction.normalize();
    
    if (direction.dot(U4DEngine::U4DVector3n(1.0,0.0,0.0))==1.0) {
        
        halfwidth.x/=uSpaces;
        
    }else if (direction.dot(U4DEngine::U4DVector3n(0.0,1.0,0.0))==1.0){
        
        halfwidth.y/=uSpaces;
        
    }else if (direction.dot(U4DEngine::U4DVector3n(0.0,0.0,1.0))==1.0){
        
        halfwidth.z/=uSpaces;
        
    }
    
    //build the aabb
    
    std::vector<U4DEngine::U4DAABB> aabbContainer;
    
    for(int n=0;n<aabbPoints.size()-1;n++){
        
        U4DEngine::U4DPoint3n minPoint=aabbPoints.at(n);
        
        U4DEngine::U4DPoint3n maxPoint=(minPoint.toVector()+halfwidth).toPoint();
        
        U4DEngine::U4DAABB aabb(minPoint,maxPoint);
        
        aabbContainer.push_back(aabb);
        
    }
    
    return aabbContainer;
    
}
