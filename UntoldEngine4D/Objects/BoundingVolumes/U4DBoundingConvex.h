//
//  U4DBoundingConvex.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/10/15.
//  Copyright © 2015 Untold Engine Studios. All rights reserved.
//

#ifndef U4DBoundingConvex_hpp
#define U4DBoundingConvex_hpp

#include <stdio.h>
#include "U4DBoundingVolume.h"
#include "U4DPoint3n.h"
#include "CommonProtocols.h"

namespace U4DEngine {
    class U4DVector3n;
    
}

namespace U4DEngine {
    
    /**
     @ingroup gameobjects
     @brief The U4DBoundingConvex represents the convex-hull bounding volumen entity
     */
    class U4DBoundingConvex:public U4DBoundingVolume{
        
    private:
        
    public:
        
        /**
         @brief Constructor of class
         */
        U4DBoundingConvex();
        
        /**
         @brief Destructor of class
         */
        ~U4DBoundingConvex();
        
        /**
         @brief Copy constructor
         */
        U4DBoundingConvex(const U4DBoundingConvex& value);
        
        /**
         @brief Copy constructor
         */
        U4DBoundingConvex& operator=(const U4DBoundingConvex& value);

        /**
         @brief Method which sets the convex-hull vertices into a container
         
         @param uConvexHull convex-hull object containing the convex-hull vertices
         */
        void setConvexHullVertices(CONVEXHULL &uConvexHull);
        
        /**
         @brief Method which returns the convex-hull vertices
         
         @return Returns the convex-hull vertices
         */
        std::vector<U4DVector3n> getConvexHullVertices();
        
        /**
         @brief Method which gets the support points in a particular direction
         
         @param uDirection direction to compute the support points
         
         @return Returns 3D points representing the support point in a particular direction
         */
        U4DPoint3n getSupportPointInDirection(U4DVector3n& uDirection);
        
    };
    
}

#endif /* U4DBoundingConvex_h */
