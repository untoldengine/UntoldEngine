//
//  U4DTriangle.h
//  UntoldEngine
//
//  Created by Harold Serrano on 8/2/15.
//  Copyright (c) 2015 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DTriangle__
#define __UntoldEngine__U4DTriangle__

#include <stdio.h>
#include <vector>
#include "U4DPoint3n.h"
#include "U4DPlane.h"
#include "U4DSegment.h"


namespace U4DEngine {

/**
 @ingroup mathengine
 @brief The U4DTriangle class implements a geometrical representation of a 3D triangle
 */
class U4DTriangle{
    
    private:
        
    public:
    
    /**
     @brief 3D vertex point of the triangle
     */
    U4DPoint3n pointA;
    
    /**
     @brief 3D vertex point of the triangle
     */
    U4DPoint3n pointB;
    
    /**
     @brief 3D vertex point of the triangle
     */
    U4DPoint3n pointC;
    
    /**
     @brief Constructor which creates a 3D triangle with vertices all set to zero components
     */
    U4DTriangle();

    /**
     @brief Constructor which creates a 3D triangle with the given vertex points
     */
    U4DTriangle(U4DPoint3n& uPointA, U4DPoint3n& uPointB, U4DPoint3n& uPointC);

    /**
     @brief Destructor for the class
     */
    ~U4DTriangle();

    /**
     @brief Copy constructor for the class
     */
    U4DTriangle(const U4DTriangle& a);

    /**
     @brief Copy constructor for the class
     
     @param a 3D triangle to copy to
     
     @return Returns a copy of the 3D triangle
     */
    U4DTriangle& operator=(const U4DTriangle& a);
    
    /**
     @brief Method which determines if two 3D triangle are equal. That is, they have the same vertex 3D points
     
     @param a 3D triangle to test
     
     @return Returns true if both triangles have the same vertex 3D points
     */
    bool operator==(const U4DTriangle& a);
    
    /**
     @brief Method which determines if two 3D triangle are NOT equal. That is, they DO NOT have the same vertex 3D points
     
     @param a 3D triangle to test
     
     @return Returns true if both triangles DO NOT have the same vertex 3D points
     */
    bool operator!=(const U4DTriangle& a);
    
    /**
     @brief Method which determins the closest 3D point on the 3D triangle from the given 3D point
     
     @param uPoint 3D point to determine closest point
     
     @return Returns the closest 3D point to the triangle from the given 3D point
     */
    U4DPoint3n closestPointOnTriangleToPoint(U4DPoint3n& uPoint);
    
    /**
     @brief Method which determines the centroid point of the triangle
     
     @return Returns a 3D point representing the centroid
     */
    U4DPoint3n getCentroid();
    
    /**
     @brief Method which determines if the 3D point lies on the 3D triangle
     
     @param uPoint 3D point to test
     
     @return Returns true if the given 3D point lies on the 3D triangle
     */
    bool isPointOnTriangle(U4DPoint3n& uPoint);
    
    /**
     @brief Method which computes the Barycentric coordinates of the 3D point in the triangle
     
     @param uPoint          3D point to compute barycentric coordinates from
     @param baryCoordinateU u-component of the barycentric coordinates of the 3D point
     @param baryCoordinateV v-component of the barycentric coordinates of the 3D point
     @param baryCoordinateW w-component of the barycentric coordinates of the 3D point
     */
    void getBarycentricCoordinatesOfPoint(U4DPoint3n& uPoint, float& baryCoordinateU, float& baryCoordinateV, float& baryCoordinateW);
    
    /**
     @brief Method which returns a 3D normal vector to the triangle. The normal vector computation follows the right-hand rule.
     
     @return Returns a 3D vector representing the normal vector to the 3D triangle
     */
    U4DVector3n getTriangleNormal();
    
    /**
     @brief Method which returns all three vertices of the 3D triangle
     
     @return Returns the three vertices of the 3D triangle
     */
    std::vector<U4DSegment> getSegments();

    /**
     @brief Method which returns a projected 3D triangle to a 3D plane
     
     @param uPlane 3D plane to compute projected 3D triangle
     
     @return Returns a 3D triangle projected to a 3D plane
     */
    U4DTriangle projectTriangleOntoPlane(U4DPlane& uPlane);
    
    /**
     @brief Method which computes the magnitude(distance) from the 3D triangle to a 3D plane
     
     @param uPlane 3D plane to compute distance
     
     @return Returns the magnitude(distance) from a 3D triangle to a 3D plane
     */
    float distanceToPlane(U4DPlane& uPlane);

    /**
     @brief Method which computes the square magnitude fromt the 3D triangle to a 3D plane
     
     @param uPlane 3D plane to compute distance
     
     @return Returns the square magnitude from a 3D triangle to a 3D plane
     */
    float distanceSquareToPlane(U4DPlane& uPlane);

    /**
     @brief Method which computes the magnitude(distance) from the 3D triangle's centroid to a 3D plane
     
     @param uPlane 3D plane to compute centroid distance from
     
     @return Returns the magnitude(distance) from the 3D triangle's centroid to a 3D plane
     */
    float centroidDistanceToPlane(U4DPlane& uPlane);

    /**
     @brief Method which computes the square magnitude(distance) from the 3D triangle's centroid to a 3D plane
     
     @param uPlane 3D plane to compute centroid distance from
     
     @return Returns the square magnitude(distance) from the 3D triangle's centroid to a 3D plane
     */
    float centroidSquareDistanceToPlane(U4DPlane& uPlane);

    /**
     @brief Method which prints the vertices of the 3D triangle to the console log window
     */
    void show();
    
    /**
     @brief Method which test if the 3D triangle is valid. That is, if the points are not colinear
     
     @return Returns true if the 3D triangle construction is valid.
     */
    bool isValid();
    
    };

}

#endif /* defined(__UntoldEngine__U4DTriangle__) */
