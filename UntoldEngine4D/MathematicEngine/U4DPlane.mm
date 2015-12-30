//
//  U4DPlane.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/30/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#include "U4DPlane.h"
#include "Constants.h"
#include <cmath>

namespace U4DEngine {
    
U4DPlane::U4DPlane(U4DVector3n& uPoint1, U4DVector3n& uPoint2, U4DVector3n& uPoint3){
    
    n=(uPoint2-uPoint1).cross(uPoint3-uPoint1);
    
    d=n.dot(uPoint1);
    
}

U4DPlane::U4DPlane(U4DVector3n& uNormal, float uDistance){
    
    n=uNormal;
    
    d=uDistance;
}

U4DPlane::U4DPlane(U4DVector3n& uNormal, U4DVector3n& uPoint){
 
    n=uNormal;
    
    d=uNormal.dot(uPoint);
    
}

U4DVector3n U4DPlane::intersectSegmentPlane(U4DVector3n& uPointA, U4DVector3n& uPointB){
    
    U4DVector3n pointAB=uPointB-uPointA;
    
    U4DVector3n intersectionPoint(0,0,0);
    
    float t=(d-n.dot(uPointA))/(n.dot(pointAB));
    
    if(t>=0.0f && t <=1.0){
        
        intersectionPoint=uPointA+pointAB*t;
    }
    
    return intersectionPoint;
}

U4DVector3n U4DPlane::closestPointToPlane(U4DVector3n& uPoint){
    
    U4DVector3n q;
    
    float t=(n.dot(uPoint)-d)/(n.magnitude());
    
    q=uPoint-n*t;
    
    return q;
    
}

float U4DPlane::distPointToPlane(U4DVector3n& uPoint){
    
    return (n.dot(uPoint)-d)/(n.magnitude());
}

U4DVector3n U4DPlane::intersetPlanes(U4DPlane& uPlane){
    
    U4DVector3n uPoint;
    
    //compute direction of intersection line
    U4DVector3n direction=n.cross(uPlane.n);
    
    //if d is zero, the planes are parallel (and separated) or coincident, so they're not considered intersecting
    
    float denom=direction.dot(direction);
    
    if (denom<U4DEngine::collisionEpsilon) {
        
        uPoint.zero();
        return uPoint;
    
    }
    
    //compute point on intersection line
    uPoint=(uPlane.n*d-n*uPlane.d).cross(direction)/denom;
  
    
    return uPoint;
}

U4DVector3n U4DPlane::intersetPlanes(U4DPlane& uPlane2, U4DPlane& uPlane3){
    
    U4DVector3n uPoint;
   
    U4DVector3n u=uPlane2.n.cross(uPlane3.n);
    
    float denom=n.dot(u);
    
    if (std::abs(denom)<U4DEngine::collisionEpsilon) {
        
        uPoint.zero();
        return uPoint; //planes do not intersect in a point
    
    }
    
    uPoint=(u*d + n.cross(uPlane2.n*uPlane3.d-uPlane3.n*uPlane2.d))/denom;
    
    return uPoint;
    
}

}