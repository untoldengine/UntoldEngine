//
//  U4DSegment.h
//  UntoldEngine
//
//  Created by Harold Serrano on 8/2/15.
//  Copyright (c) 2015 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DSegment__
#define __UntoldEngine__U4DSegment__

#include <stdio.h>
#include <vector>
#include <iostream>
#include "U4DPoint3n.h"

namespace U4DEngine {
    
/**
 @brief The U4DSegment class implements a geometrical representation of a segment in 3D space
 */
class U4DSegment{
    
private:
        
public:
    
    /*!
     @brief  3D endPoint of segment
     */
    U4DPoint3n pointA;
    
    /*!
     @brief  3D endPoint of segment
     */
    U4DPoint3n pointB;
    
    /**
     @brief Constructor which creates a segment with 3D points set to zero-components
     */
    U4DSegment();
    
    /*!
     @brief  Constructor which creates a segment with the given 3D points
     */
    U4DSegment(U4DPoint3n& uPointA,U4DPoint3n& uPointB);
    
    /*!
     @brief  Destructor of the class
     */
    ~U4DSegment();
    
    /**
     @brief Copy constructor for the 3D segment
     */
    U4DSegment(const U4DSegment& a);
    
    /**
     @brief Copy constructor for the 3D segment
     
     @param a 3D segment to copy
     
     @return Returns a copy of the 3D segment
     */
    U4DSegment& operator=(const U4DSegment& a);
    
    /**
     @brief Method which compares if two 3D segments are equal
     
     @param uSegment 3D segments to compare
     
     @return Returns true if the 3D segments are equal
     */
    bool operator==(const U4DSegment& uSegment);
    
    /**
     @brief Method which compares if two 3D segments are NOT equal
     
     @param uSegment 3D segments to compare
     
     @return Returns true if the 3D segments are NOT equal
     */
    bool operator!=(const U4DSegment& uSegment);
    
    /**
     @brief Method which flips the direction of the 3D segment. That is, point AB becomes point BA
     
     @return Returns the flip direction of the 3D segment. That is, point AB becomes point BA
     */
    U4DSegment negate();
    
    /*!
     @brief  Determines the closest 3D point on the 3D segment to a 3D point
     
     @param uPoint 3D point to determine closest point
     
     @return Returns the 3D point closest on segment
     */
    U4DPoint3n closestPointOnSegmentToPoint(U4DPoint3n& uPoint);
    
    /*!
     @brief  Determines if the point is on the segment
     
     @param uPoint 3D point to test if it lies on segment
     
     @return Returns True if point is on segment
     */
    bool isPointOnSegment(U4DPoint3n& uPoint);
    
    /*!
     @brief  Returns the squared distance between a 3D point and segment
     
     @param uPoint 3D point to calculate distance from
     
     @return Squared distance between point and segment
     */
    float sqDistancePointSegment(U4DPoint3n& uPoint);
    
    /**
     @brief Method which normalizes the square distance(magnitude) between a 3D point and the segment
     
     @param uPoint 3D point to calculate distance from
     
     @return Returns the normalized square distance between point and segment
     */
    float normalizedSquareDistancePointSegment(U4DPoint3n& uPoint);
    
    /**
     @brief Method which computes the Barycentric coordinates of the 3D point in the segment
     
     @param uPoint          3D point to compute barycentric coordinates from
     @param baryCoordinateU u-component of the barycentric coordinates of the 3D point
     @param baryCoordinateV v-componenet of the barycentric coordinates of the 3D point
     */
    void getBarycentricCoordinatesOfPoint(U4DPoint3n& uPoint, float& baryCoordinateU, float& baryCoordinateV);
    
    /**
     @brief Method which returns the 3D endpoints of the segments
     
     @return Returns the endpoints of the segment
     */
    std::vector<U4DPoint3n> getPoints();
    
    /**
     @brief Method which prints the 3D endpoints of the segments to the console log window
     */
    void show();
    
    /**
     @brief Method which tests if the segment is a valid 3D segment
     
     @return Returns true if the segment is valid
     */
    bool isValid();
};
    
}

#endif /* defined(__UntoldEngine__U4DSegment__) */
