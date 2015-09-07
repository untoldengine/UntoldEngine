//
//  U4DSegment.h
//  UntoldEngine
//
//  Created by Harold Serrano on 8/2/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DSegment__
#define __UntoldEngine__U4DSegment__

#include <stdio.h>
#include "U4DPoint3n.h"

namespace U4DEngine {
    
/// The U4DSegment class implements a segment in 3D space.

class U4DSegment{
    
private:
    
    /*!
     @brief  Point A on segment
     */
    U4DPoint3n pointA;
    
    /*!
     @brief  Point B on segment
     */
    U4DPoint3n pointB;
    
    /**
     @brief  barycentric point u of segment
     */
    float barycentricU;
    
    /**
     @brief  barycentric point v of segment
     */
    float barycentricV;
    
public:
    
    /*!
     @brief  Constructor
     */
    U4DSegment(U4DPoint3n& uPointA,U4DPoint3n& uPointB);
    
    /*!
     @brief  Destructor
     */
    ~U4DSegment();
    
    bool operator==(const U4DSegment& uSegment);
    
    U4DSegment negate();

    /*!
     @brief  Determines the closest point on the segment to a point
     
     @param uPoint Point value
     
     @return Point closest on segment
     */
    U4DPoint3n closestPointOnSegmentToPoint(U4DPoint3n& uPoint);
    
    /*!
     @brief  Determines if the point is on the segment
     
     @param uPoint Point value
     
     @return true if point is on segment
     */
    bool isPointOnSegment(U4DPoint3n& uPoint);
    
    /*!
     @brief  Returns the squared distance between point C and segment
     
     @param uPoint Point value
     
     @return Squared distance between point and segment
     */
    float sqDistancePointSegment(U4DPoint3n& uPoint);
    
    void getBarycentricCoordinatesOfPoint(U4DPoint3n& uPoint, float& baryCoordinateU, float& baryCoordinateV);
    
};
    
}

#endif /* defined(__UntoldEngine__U4DSegment__) */
