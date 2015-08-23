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

namespace U4DEngine {
    
class U4DPlane{
    
private:
    
public:
  
    U4DVector3n n;
    
    float d;
    
    U4DPlane(U4DVector3n& a, U4DVector3n& b, U4DVector3n& c);
    
    U4DPlane(U4DVector3n& uNormal, float uDistance);
    
    U4DPlane(U4DVector3n& uNormal, U4DVector3n& uPoint);
    
    ~U4DPlane(){};
    
    U4DPlane(const U4DPlane& a):n(a.n),d(a.d){};
    
    inline U4DPlane& operator=(const U4DPlane& a){
        
        n=a.n;
        d=a.d;
        
        return *this;
        
    };
    
    
    U4DVector3n intersectSegmentPlane(U4DVector3n& pointA, U4DVector3n& pointB);
    
    U4DVector3n closestPointToPlane(U4DVector3n& uPoint);
    
    float distPointToPlane(U4DVector3n& uPoint);
    
    /*!
     *  @brief  Given planes plane1 and plane2, computer line L=p+t*d of their intersection.
     *
     *  @param uPlane plane
     *
     *  @return returns intersection vector
     */
    U4DVector3n intersetPlanes(U4DPlane& uPlane);
    
    /*!
     *  @brief  Computes the point uPoint at which three planes intersect (if at all)
     *
     *  @param uPlane2 plane 2
     *  @param uPlane3 plane 3
     *
     *  @return point where all three planes intersect
     */
    U4DVector3n intersetPlanes(U4DPlane& uPlane2, U4DPlane& uPlane3);
};
    
}

#endif /* defined(__UntoldEngine__U4DPlane__) */
