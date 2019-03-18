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
    
}

