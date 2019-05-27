//
//  U4DSphere.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/28/16.
//  Copyright © 2016 Untold Engine Studios. All rights reserved.
//

#ifndef U4DSphere_hpp
#define U4DSphere_hpp

#include <stdio.h>
#include "U4DPoint3n.h"
#include "U4DPlane.h"

namespace U4DEngine {

    /**
     @ingroup mathengine
     @brief The U4DSphere class implements a mathematical representation of a sphere
     */
    class U4DSphere {
        
    private:
        
    public:
        
        /**
         @brief 3D point representing the center of a sphere
         */
        U4DPoint3n center;
        
        /**
         @brief Radius of the sphere
         */
        float radius;
        
        /**
         @brief Constructor which constructs a sphere with center location set to origin and radius equal to zero.
         */
        U4DSphere();
        
        /**
         @brief Constructor which constructs a sphere with the given center location and radius
         */
        U4DSphere(U4DPoint3n &uCenter, float uRadius);
        
        /**
         @brief Destructor of the class
         */
        ~U4DSphere();
        
        /**
         @brief Method which sets the center location of the sphere
         
         @param uCenter Center location of the sphere
         */
        void setCenter(U4DPoint3n &uCenter);
        
        /**
         @brief Method which sets the radius of the sphere
         
         @param uRadius Radius of the sphere
         */
        void setRadius(float uRadius);
        
        /**
         @brief Method which returns the center location of the sphere
         
         @return Returns the center location of the sphere
         */
        U4DPoint3n getCenter();
        
        /**
         @brief Method which returns the radius of the sphere
         
         @return Returns the radius of the sphere
         */
        float getRadius();
        
        /**
         @brief Method which test the intersection between two spheres
         
         @param uSphere Sphere to test intersection with
         
         @return Returns true if two spheres are intersecting
         */
        bool intersectionWithVolume(U4DSphere &uSphere);
        
        /**
         @brief Method which test the intersection between two spheres and returns the intersection plane
         
         @param uSphere Sphere to test intersection with
         @param uPlane Intersection plane created during the intersection
         
         @return Returns true if two spheres are intersecting
         */
        bool intersectionWithVolume(U4DSphere &uSphere, U4DPlane &uPlane);
        
    };

}

#endif /* U4DSphere_hpp */
