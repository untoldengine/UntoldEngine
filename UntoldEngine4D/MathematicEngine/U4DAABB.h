//
//  U4DAABB.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/28/16.
//  Copyright © 2016 Untold Engine Studios. All rights reserved.
//

#ifndef U4DAABB_hpp
#define U4DAABB_hpp

#include <stdio.h>
#include "U4DPoint3n.h"
#include "U4DVector3n.h"
#include <float.h>

namespace U4DEngine {
    class U4DSphere;
    class U4DSegment;
    class U4DTriangle;
    class U4DPlane;
}

namespace U4DEngine {
    
    /**
     @ingroup mathengine
     @brief The U4DAABB class implements a mathematical representation of an Axis-Aligned Bounding Box
     */
    class U4DAABB {
        
    private:
        
        /**
         @brief Longest Volume dimension 3D vector of an AABB
         */
        U4DVector3n longestAABBDimensionVector;
        
    public:
        
        /**
         @brief Minimum 3D point location of the AABB
         */
        U4DPoint3n minPoint;
        
        /**
         @brief Maximum 3D point location of the AABB
         */
        U4DPoint3n maxPoint;
        
        /**
         @brief Constructor which creates a AABB with minimum 3D point location, maximum 3D point location and longest Dimension 3D vector set to zero
         */
        U4DAABB();
        
        /**
         @brief Constructor which creates a AABB with given minimum 3D point location and maximum 3D point location
         */
        U4DAABB(U4DPoint3n &uMinPoint, U4DPoint3n &uMaxPoint);
        
        /**
         @brief Constructor which creates a AABB with given minimum 3D point halfwidth
         */
        U4DAABB(float uX, float uY, float uZ, U4DPoint3n &uCenter);
        
        /**
         @brief Copy constructor for the class
         @param a AABB to copy to
         */
        U4DAABB(const U4DAABB& a);
        
        /**
         @brief Copy constructor for the class
         
         @param a AABB to copy to
         
         @return returns a copy of the AABB
         */
        U4DAABB& operator=(const U4DAABB& a);
        
        /**
         @brief Destructor for the class
         */
        ~U4DAABB();
        
        /**
         @brief Method which sets the minimum 3D point location for the AABB
         
         @param uMinPoint Minimum 3D point location
         */
        void setMinPoint(U4DPoint3n& uMinPoint);
        
        /**
         @brief Method which sets the maximum 3D point location for the AABB
         
         @param uMaxPoint Maximum 3D point location
         */
        void setMaxPoint(U4DPoint3n& uMaxPoint);
        
        /**
         @brief Method which returns the minimum 3D point of the AABB
         
         @return Returns the minimum 3D point of the AABB
         */
        U4DPoint3n getMinPoint();
        
        /**
         @brief Method which returns the maximum 3D point of the AABB
         
         @return Returns the maximum 3D point of the AABB
         */
        U4DPoint3n getMaxPoint();
        
        /**
         @brief Method which tests the intersection between two AABBs
         
         @param uAABB AABB object to test intersection with
         
         @return Returns true if two AABBs intersection occurred
         */
        bool intersectionWithVolume(U4DAABB *uAABB);
        
        /**
         @brief Method which test an intersection between an AABB and a sphere
         
         @param uSphere Sphere object to test intersection with
         
         @return Returns true if an intersection between an AABB and a sphere occurred
         */
        bool intersectionWithVolume(U4DSphere &uSphere);
        
        /**
         @brief Method which test an intersection between an AABB and a sphere
         
         @param uSphere Sphere object to test intersection with
         
         @param uPoint point closest to intersection on AABB
         
         @return Returns true if an intersection between an AABB and a sphere occurred
         */
        bool intersectionWithVolume(U4DSphere &uSphere, U4DPoint3n &uPoint);
        
        /**
         @brief Method which sets the longest Dimension vector of the AABB
         
         @param uLongestAABBDimensionVector Longest dimension vector of the AABB
         */
        void setLongestAABBDimensionVector(U4DVector3n& uLongestAABBDimensionVector);
        
        /**
         @brief Method which returns the longest dimension vector of the AABB
         
         @return Returns the longest dimension vector of the AABB
         */
        U4DVector3n getLongestAABBDimensionVector();

        /**
         @brief Method which computes the square magnitude(distance) of a 3D point to the AABB
         
         @param uPoint 3D point to compute square magnitude
         
         @return Returns the square magnitude of a 3D point to the AABB. That is, it does not compute the square root of the magnitude.
         */
        float squareDistanceToPoint(U4DPoint3n& uPoint);
        
        /**
         * @brief Compute if the AABB is intersecting with a segment
         * 
         * @param uSegment segment
         * @return true if intersection occurs
         */
        bool intersectionWithSegment(U4DSegment &uSegment);
        
        /**
         * @brief Gets the center point of the AABB
         * 
         * @return center point
         */
        U4DPoint3n getCenter();
        
        /**
         * @brief Computes if 3D point is within the AABB
         * 
         * @param uPoint 3D point
         * @return true if point lies within the AABB
         */
        bool isPointInsideAABB(U4DPoint3n &uPoint);
        
        /**
         * @brief Gets the halfwidth of the AABB 
         * 
         * @return halfwidth vector
         */
        U4DVector3n getHalfWidth();
        
        /**
         * @brief determines intersection with triangle
         *
         * @param uTriangle triangle to test intersection
         *
         * @return true if the aabb intersects with the triangle
         */
        bool intersectionWithTriangle(U4DTriangle &uTriangle);
        
        /**
         * @brief tests intersection with of AABB with plane
         *
         * @param uPlane plane to test intersection
         *
         * @return true if AABB intersects the plane
         */
        bool intersectionWithPlane(U4DPlane &uPlane);
        
        /**
         * @brief Computes the closest point on the AABB to an specified point
         *
         * @param uPoint Point provided by the user
         *
         * @param uClosestPoint Closest point to the provided point
         */
        void closestPointOnAABBToPoint(U4DPoint3n &uPoint, U4DPoint3n &uClosestPoint);
        
        /**
         * @brief determines the aabb plane the point lies. Recall that the AABB contains 6 planes
         *
         * @param uPoint point to determine in which plane it lies
         *
         * @param uPlane plane where the given point lies
         
         * @return true if the point lies on any of the 6 planes of the aabb
         */
        bool aabbPlanePointLies(U4DPoint3n &uPoint, U4DPlane &uPlane);
        
    };
    
}

#endif /* U4DAABB_hpp */
