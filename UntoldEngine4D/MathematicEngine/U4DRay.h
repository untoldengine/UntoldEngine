//
//  U4DRay.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/17/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DRay_hpp
#define U4DRay_hpp

#include <stdio.h>
#include <cmath>
#include <float.h>
#include "U4DPoint3n.h"
#include "U4DVector3n.h"
#include "U4DPlane.h"
#include "U4DTriangle.h"
#include "U4DAABB.h"

namespace U4DEngine {
    
    class U4DRay {
        
    private:
    
    public:
    
        /**
         @brief  3D origin of ray
         */
        U4DPoint3n origin;
        
        /**
         @brief 3D direction of ray
         */
        U4DVector3n direction;
        
        /**
         @brief ray constructor
         */
        U4DRay();
        
        /**
         @brief ray constructor with origing and direction
         
         @param uOrigin Ray origin
         @param uDirection Ray direction
         */
        U4DRay(U4DPoint3n &uOrigin, U4DVector3n &uDirection);
        
        /**
         @brief ray destructor
         */
        ~U4DRay();
        
        /**
         @brief Copy constructor for the Ray
         */
        U4DRay(const U4DRay& a);
        
        /**
         @brief Copy constructor for the Ray
         
         @param a 3D ray to copy
         
         @return Returns a copy of the 3D ray
         */
        U4DRay& operator=(const U4DRay& a);
        
        
        /**
         @brief tests intersection with a plane

         @param uPlane Plane to test intersection
         @param uIntersectionPoint ray intersection point
         @param uIntersectionTime ray intersection time
         @return true if the ray intersects the plane
         */
        bool intersectPlane(U4DPlane &uPlane, U4DPoint3n &uIntersectionPoint, float &uIntersectionTime);
        
        /**
         @brief test intersection with a 3D triangle

         @param uTriangle 3D Triangle to test intersection
         @param uIntersectionPoint ray intersection point
         @param uIntersectionTime ray intersection time
         @return true if the ray intersects the triangle
         */
        bool intersectTriangle(U4DTriangle &uTriangle, U4DPoint3n &uIntersectionPoint, float &uIntersectionTime);
        
        /**
         @brief test intersection with an AABB Box
         
         @param uAABB AABB to test intersection
         @param uIntersectionPoint ray intersection point
         @param uIntersectionTime ray intersection time
         @return true if the ray intersects the AABB
         */
        bool intersectAABB(U4DAABB &uAABB, U4DPoint3n &uIntersectionPoint, float &uIntersectionTime);
        
    };
    
}

#endif /* U4DRay_hpp */
