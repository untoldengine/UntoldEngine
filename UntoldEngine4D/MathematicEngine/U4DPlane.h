//
//  U4DPlane.h
//  UntoldEngine
//
//  Created by Harold Serrano on 5/30/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DPlane__
#define __UntoldEngine__U4DPlane__

#include <stdio.h>
#include <iostream>
#include "U4DVector3n.h"
#include "U4DPoint3n.h"
#include "U4DSegment.h"

namespace U4DEngine {
    
    class U4DPlane{
        
        private:
            
        public:
        
            U4DVector3n n; //plane normal. Points x on the plane satisfy n.dox(x)=d
            
            float d; //d=n.dot(p) for a given point p on the plane
        
            U4DPlane(U4DPoint3n& a, U4DPoint3n& b, U4DPoint3n& c);
            
            U4DPlane(U4DVector3n& uNormal, float uDistance);
            
            U4DPlane(U4DVector3n& uNormal, U4DPoint3n& uPoint);
            
            ~U4DPlane();
            
            U4DPlane(const U4DPlane& a);
        
            inline U4DPlane& operator=(const U4DPlane& a);
        
            U4DPoint3n closestPointToPlane(U4DPoint3n& uPoint);
            
            float magnitudeOfPointToPlane(U4DPoint3n& uPoint);
        
            float magnitudeSquareOfPointToPlane(U4DPoint3n& uPoint);
        
            bool intersectSegment(U4DSegment& uSegment, U4DPoint3n& uIntersectionPoint);
        
            bool intersectPlane(U4DPlane& uPlane, U4DPoint3n& uIntersectionPoint, U4DVector3n& uIntersectionVector);
        
            //compute the point at which the three planes intersect (if at all)
            bool intersectPlanes(U4DPlane& uPlane2, U4DPlane& uPlane3, U4DPoint3n& uIntersectionPoint);
    };
    
}

#endif /* defined(__UntoldEngine__U4DPlane__) */
