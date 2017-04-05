//
//  U4DAABB.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/28/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "U4DAABB.h"
#include "U4DSphere.h"
#include "U4DSegment.h"
#include <cmath>
#include "Constants.h"

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
    
    bool U4DAABB::intersectionWithSegment(U4DSegment &uSegment){
        
        U4DPoint3n c=(minPoint+maxPoint)*0.5;  //box center point
        U4DVector3n e=maxPoint.toVector()-c.toVector();    //box halflengths extends
        U4DPoint3n m=(uSegment.pointA+uSegment.pointB)*0.5; //segment midpoint
        U4DVector3n d=uSegment.pointB.toVector()-m.toVector();  //segment halflength vector
        m=(m-c).toPoint();  //Translate box and segment to origin
        
        //try world coordinates axes as separating axis
        
        float adx=std::abs(d.x);
        if(std::abs(m.x)>e.x+adx) return false;
        
        float ady=std::abs(d.y);
        if(std::abs(m.y)>e.y+ady) return false;
        
        float adz=std::abs(d.z);
        if(std::abs(m.z)>e.z+adz) return false;
        
        //add in epsilon to counteract arithmetic errors when segment is near or parallel to a coordinate axis
        
        adx+=U4DEngine::zeroEpsilon;
        ady+=U4DEngine::zeroEpsilon;
        adz+=U4DEngine::zeroEpsilon;
        
        //try cross product of segment direction vector with coordinate axis
        if (std::abs(m.y*d.z-m.z*d.y)>(e.y*adz+e.z*ady)) return false;
        if (std::abs(m.z*d.x-m.x*d.z)>(e.x*adz+e.z*adx)) return false;
        if (std::abs(m.x*d.y-m.y*d.x)>(e.x*ady+e.y*adx)) return false;
        
        //no separating axis found; segment must be overlapping AABB
        return true;
    }
    
}
