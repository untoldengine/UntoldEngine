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
    
    U4DPlane::U4DPlane(){
        n.zero();
        d=0.0;
    }
    
    //given three noncollinear points (ordered CCW), compute plane equation
    U4DPlane::U4DPlane(U4DPoint3n& uPoint1, U4DPoint3n& uPoint2, U4DPoint3n& uPoint3){
        
        n=(uPoint1-uPoint2).cross(uPoint1-uPoint3);
        
        n.normalize();
        
        d=n.dot(uPoint1.toVector());
        
    }

    U4DPlane::U4DPlane(U4DVector3n& uNormal, float uDistance){
        
        n=uNormal;
        
        d=uDistance;
        
    }

    //compute plane equation
    U4DPlane::U4DPlane(U4DVector3n& uNormal, U4DPoint3n& uPoint){
     
        n=uNormal;
        
        d=n.dot(uPoint.toVector());
        
    }
    
    U4DPlane::~U4DPlane(){}
    
    U4DPlane::U4DPlane(const U4DPlane& a):n(a.n),d(a.d){}
    
    U4DPlane& U4DPlane::operator=(const U4DPlane& a){
        
        n=a.n;
        d=a.d;
        
        return *this;
        
    };


    U4DPoint3n U4DPlane::closestPointToPlane(U4DPoint3n& uPoint){
        
        U4DPoint3n q;
        
        float t=(n.dot(uPoint.toVector())-d)/(n.dot(n));
        
        q=(uPoint.toVector()-n*t).toPoint();
        
        return q;
        
    }

    float U4DPlane::magnitudeOfPointToPlane(U4DPoint3n& uPoint){
        
        return (n.dot(uPoint.toVector())-d)/(n.magnitude());
    }
    
    float U4DPlane::magnitudeSquareOfPointToPlane(U4DPoint3n& uPoint){
        
        return (n.dot(uPoint.toVector())-d)/(n.magnitudeSquare());
        
    }
    
    bool U4DPlane::intersectSegment(U4DSegment& uSegment, U4DPoint3n& uIntersectionPoint){
        
        U4DVector3n pointAB=uSegment.pointA-uSegment.pointB;
        
        float t=(d-n.dot(uSegment.pointA.toVector()))/(n.dot(pointAB));
        
        //if t>0 compute and return intersection point
        if(t>=0.0f && t<=1.0){
            
            uIntersectionPoint=(uSegment.pointA.toVector()+pointAB*t).toPoint();
            
            return true;
        }
        
        return false;
    }

    bool U4DPlane::intersectPlane(U4DPlane& uPlane, U4DPoint3n& uIntersectionPoint, U4DVector3n& uIntersectionVector){
        

        //compute direction of intersection line
        U4DVector3n direction=n.cross(uPlane.n);
        
        //if denom is zero, the planes are parallel (and separated) or coincident, so they're not considered intersecting
        
        float denom=direction.dot(direction);
        
        if (denom<U4DEngine::zeroPlaneIntersectionEpsilon) {
            
            return false;
        
        }
        
        //compute point on intersection line
        uIntersectionPoint=((uPlane.n*d-n*uPlane.d).cross(direction)/denom).toPoint();
      
        //set direction as intersection vector
        uIntersectionVector=direction;
        
        return true;
    }
 
    //compute the point at which the three planes intersect (if at all)
    bool U4DPlane::intersectPlanes(U4DPlane& uPlane2, U4DPlane& uPlane3, U4DPoint3n& uIntersectionPoint){
       
        U4DVector3n u=uPlane2.n.cross(uPlane3.n);
        
        //if denom is zero, the planes are parallel (and separated) or coincident, so they're not considered intersecting
        float denom=n.dot(u);
        
        
        if (std::abs(denom)<U4DEngine::zeroEpsilon) {
            
            return false; //planes do not intersect in a point
        
        }
        
        uIntersectionPoint=((u*d + n.cross(uPlane2.n*uPlane3.d-uPlane3.n*uPlane2.d))/denom).toPoint();
        
        return true;
        
    }

}