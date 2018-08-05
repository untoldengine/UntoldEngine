//
//  U4DPlane.h
//  UntoldEngine
//
//  Created by Harold Serrano on 5/30/15.
//  Copyright (c) 2015 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DPlane__
#define __UntoldEngine__U4DPlane__

#include <stdio.h>
#include <iostream>
#include "U4DVector3n.h"
#include "U4DPoint3n.h"
#include "U4DSegment.h"

namespace U4DEngine {
    
    /**
     @brief The U4DPlane class implements a mathematical representation of a 3D plane
     */
    class U4DPlane{
        
        private:
            
        public:
        
        /**
         @brief Plane Normal 3D vector. The point on a plane satisfy n.dox(x)=d
         */
        U4DVector3n n;
        
        /**
         @brief Distance of a 3D point to the plane. d=n.dot(p) for a given p on the plane
         */
        float d;
    
        /**
         @brief Constructor which creates a 3D plane with zero normal vector and zero distance from point to plane
         */
        U4DPlane();
    
        /**
         @brief Constructor which creates a 3D plane given three noncollinear points (ordered CCW). This constructor in essence computes the plane equation
         */
        U4DPlane(U4DPoint3n& uPoint1, U4DPoint3n& uPoint2, U4DPoint3n& uPoint3);
        
        /**
         @brief Constructor which creates a 3D plane given a normal vector and the distance from a point to plane
         */
        U4DPlane(U4DVector3n& uNormal, float uDistance);
        
        /**
         @brief Constructor which creates a 3D plane given a normal vector and a 3D point in space
         */
        U4DPlane(U4DVector3n& uNormal, U4DPoint3n& uPoint);
        
        /**
         @brief Destructor of the class
         */
        ~U4DPlane();
        
        /**
         @brief Copy constructor for a 3D plane object
         */
        U4DPlane(const U4DPlane& a);
    
        /**
         @brief Copy constructor for a 3D plane object
         
         @param a 3D plane to copy
         
         @return Returns a copy of the 3D plane object
         */
        U4DPlane& operator=(const U4DPlane& a);
    
        /**
         @brief Method which computes the closest 3D point to a plane
         
         @param uPoint 3D point to compute the closest point to a plane
         
         @return Returns the closest 3D point to the plane
         */
        U4DPoint3n closestPointToPlane(U4DPoint3n& uPoint);
        
        /**
         @brief Method which computes the magnitude(distance) of a 3D point to a plane
         
         @param uPoint 3D point to compute the magnitude(distance) to a plane
         
         @return Returns the magnitude(distance) of a 3D point to plane
         */
        float magnitudeOfPointToPlane(U4DPoint3n& uPoint);
    
        /**
         @brief Method which computes the square magnitude(distance) of a 3D point to a plane. That is, it does not compute the square root of the magnitude
         
         @param uPoint 3D point to compute the square magnitude(distance) to a plane
         
         @return Returns the square magnitude(distance) of a 3D point to plane. That is, it does not compute the square root of the magnitude
         */
        float magnitudeSquareOfPointToPlane(U4DPoint3n& uPoint);
    
        /**
         @brief Method which computes if a 3D segment intersects a 3D plane
         
         @param uSegment           3D segment to test intersection
         @param uIntersectionPoint 3D point where intersection occurs.
         
         @return Returns true if the 3D segment intersects the 3D plane
         */
        bool intersectSegment(U4DSegment& uSegment, U4DPoint3n& uIntersectionPoint);
    
        /**
         @brief Method which computes if two 3D planes intersect
         
         @param uPlane              3D plane to test intersection
         @param uIntersectionPoint  3D point where intersection occurs
         @param uIntersectionVector 3D vector produced by the intersection between the two planes
         
         @return Returns true if two 3D planes intersect
         */
        bool intersectPlane(U4DPlane& uPlane, U4DPoint3n& uIntersectionPoint, U4DVector3n& uIntersectionVector);
    
        /**
         @brief Method which computes if three 3D planes intersect
         
         @param uPlane2            First 3D plane to test intersection
         @param uPlane3            Second 3D plane to test intersection
         @param uIntersectionPoint 3D point where intersection occurs
         
         @return Returns true if three 3D planes intersect
         */
        bool intersectPlanes(U4DPlane& uPlane2, U4DPlane& uPlane3, U4DPoint3n& uIntersectionPoint);
        
        
        /**
         @brief Compute the angle between planes. The plane normals must be normalized
         
         @param uPlane  Plane to compute angle
         
         @return Returns the angle in degrees
         */
        float angle(U4DPlane &uPlane);
        
    };
    
}

#endif /* defined(__UntoldEngine__U4DPlane__) */
