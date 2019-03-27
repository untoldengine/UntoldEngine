//
//  U4DRay.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/17/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "U4DRay.h"
#include "Constants.h"

namespace U4DEngine {
    
    U4DRay::U4DRay(){
        
    }
    
    U4DRay::~U4DRay(){
        
    }

    U4DRay::U4DRay(const U4DRay& a):origin(a.origin),direction(a.direction){
        
    }
    
    U4DRay::U4DRay(U4DPoint3n &uOrigin, U4DVector3n &uDirection){
        
        origin=uOrigin;
        direction=uDirection;
        
    }
    
    U4DRay& U4DRay::operator=(const U4DRay& a){
        
        origin=a.origin;
        direction=a.direction;
        
        return *this;
    }
    
    bool U4DRay::intersectPlane(U4DPlane &uPlane, U4DPoint3n &uIntersectionPoint, float &uIntersectionTime){
        
        //convert point to vector
        U4DVector3n originVector=origin.toVector();
        
        //equation to get hit time=(d-n.origin)/(n.direction)
        //d and n are part of the 3D plane.
        //I basically find the intersection between the plane (n.x)=d and the ray: origin+t*direction
        uIntersectionTime=(uPlane.d-uPlane.n.dot(originVector))/(uPlane.n.dot(direction));
        
        if (uIntersectionTime>U4DEngine::zeroEpsilon) {
            
            uIntersectionPoint=(originVector+direction*uIntersectionTime).toPoint();
            
            return true;
        }
        
        //else no intersection
        
        return false;
        
    }
    
    bool U4DRay::intersectTriangle(U4DTriangle &uTriangle, U4DPoint3n &uIntersectionPoint, float &uIntersectionTime){
        
        //get the plane from the triangle
        U4DPlane plane(uTriangle.pointA,uTriangle.pointB,uTriangle.pointC);
        
        //test if the ray intersects the plane
        
        if (intersectPlane(plane, uIntersectionPoint, uIntersectionTime)) {
            
            //if it does, get the intersection point and check if the point is inside the triangle
            if(uTriangle.isPointOnTriangle(uIntersectionPoint)){
                
                //return true with intersection point and time
                return true;
                
            }
            
        }
        
        //else no intersection
        return false;
    }
    
    bool U4DRay::intersectAABB(U4DAABB &uAABB, U4DPoint3n &uIntersectionPoint, float &uIntersectionTime){
        
        //Refer to page 181 in Real Time Collision Detection
        
        //declare tmin and tmax
        float tMin=0.0f;
        float tMax=FLT_MAX;
        
        //For ease of use load all the min and max values of the AABB into an array. We will use this in a for loop.
        
        float minValues[3]={uAABB.minPoint.x,uAABB.minPoint.y,uAABB.minPoint.z};
        float maxValues[3]={uAABB.maxPoint.x,uAABB.maxPoint.y,uAABB.maxPoint.z};
        float originValues[3]={origin.x,origin.y,origin.z};
        float d[3]={1/direction.x,1/direction.y,1/direction.z};
        
        //go through all three slab of the AABB
        for(int i=0; i<3; i++) {
           
            //Check if the coordinates of the ray is paraller and lies exactly on the slab of the AABB
            if(std::abs(d[i])<U4DEngine::zeroEpsilon){
                
                if (originValues[i]<minValues[i] || originValues[i]>maxValues[i]) {
                    return false;
                }
                
            }else{
                
                //Compute the intersection t value of ray with near and far plane of slab
                float t1=(minValues[i]-originValues[i])*d[i];
                float t2=(maxValues[i]-originValues[i])*d[i];
                
                //make t1 be intersection with near plane, t2 with far plane
                if(t1>t2) std::swap(t1,t2);
                
                //compute the intersection of slab intersection intervals
                tMin=std::max(tMin, t1);
                tMax=std::min(tMax,t2);
                
                if (tMin>tMax) {
                    return false;
                }
                
            }
           
        }
        
        //set intersection time and point
        uIntersectionTime=tMin;
        
        uIntersectionPoint=(origin.toVector()+direction*uIntersectionTime).toPoint();
        
        return true;
        
    }
    
}

