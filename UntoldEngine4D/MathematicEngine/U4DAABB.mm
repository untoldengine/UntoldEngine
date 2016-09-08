//
//  U4DAABB.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/28/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "U4DAABB.h"
#include "U4DSphere.h"

namespace U4DEngine {

    U4DAABB::U4DAABB(){
        
        minPoint.zero();
        maxPoint.zero();
        longestAABBDimensionVector.zero();
        
    }
    
    U4DAABB::~U4DAABB(){
        
    }
    
    U4DAABB::U4DAABB(U4DPoint3n &uMinPoint, U4DPoint3n &uMaxPoint){
        
        minPoint=uMinPoint;
        maxPoint=uMaxPoint;
        
    }
    
    void U4DAABB::setMinPoint(U4DPoint3n& uMinPoint){
        
        minPoint=uMinPoint;
    }
    
    void U4DAABB::setMaxPoint(U4DPoint3n& uMaxPoint){
        
        maxPoint=uMaxPoint;
        
    }
    
    U4DPoint3n U4DAABB::getMinPoint(){
        return minPoint;
    }
    
    U4DPoint3n U4DAABB::getMaxPoint(){
        return maxPoint;
    }
    
    
    bool U4DAABB::intersectionWithVolume(U4DAABB *uAABB){
        
        //Exit with no intersection if separated along an axis
        
        if (maxPoint.x<uAABB->minPoint.x || minPoint.x>uAABB->maxPoint.x) return false;
        if (maxPoint.y<uAABB->minPoint.y || minPoint.y>uAABB->maxPoint.y) return false;
        if (maxPoint.z<uAABB->minPoint.z || minPoint.z>uAABB->maxPoint.z) return false;
        
        //overlapping on all axes means AABBs are intersecting
        
        return true;
    }
    
    float U4DAABB::squareDistanceToPoint(U4DPoint3n& uPoint){
        float sqDistance=0.0;
        
        //for each axix count any excess distance outside box extents. See page 131 in Real-Time Collision Detection
        
        //x-axis
        if (uPoint.x<minPoint.x) sqDistance+=(minPoint.x-uPoint.x)*(minPoint.x-uPoint.x);
        if (uPoint.x>maxPoint.x) sqDistance+=(uPoint.x-maxPoint.x)*(uPoint.x-maxPoint.x);
        
        
        //y-axis
        if (uPoint.y<minPoint.y) sqDistance+=(minPoint.y-uPoint.y)*(minPoint.y-uPoint.y);
        if (uPoint.y>maxPoint.y) sqDistance+=(uPoint.y-maxPoint.y)*(uPoint.y-maxPoint.y);
        
        //z-axis
        if (uPoint.z<minPoint.z) sqDistance+=(minPoint.z-uPoint.z)*(minPoint.z-uPoint.z);
        if (uPoint.z>maxPoint.z) sqDistance+=(uPoint.z-maxPoint.z)*(uPoint.z-maxPoint.z);
        
        
        return sqDistance;
    }
    
    bool U4DAABB::intersectionWithVolume(U4DSphere &uSphere){
        
        //Compute squared distance between sphere center and AABB
        
        float sqDistance=squareDistanceToPoint(uSphere.center);
        
        //Sphere and AABB intersect if the (squared) distance
        //between them is less than the (squared) sphere radius
        
        return sqDistance<=uSphere.radius*uSphere.radius;
        
    }
    
    void U4DAABB::setLongestAABBDimensionVector(U4DVector3n& uLongestAABBDimensionVector){
        longestAABBDimensionVector=uLongestAABBDimensionVector;
    }
    
    U4DVector3n U4DAABB::getLongestAABBDimensionVector(){
        return longestAABBDimensionVector;
    }
    
}