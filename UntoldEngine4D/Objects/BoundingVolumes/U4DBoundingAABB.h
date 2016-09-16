//
//  U4DBoundingAABB.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/15/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DBoundingAABB__
#define __UntoldEngine__U4DBoundingAABB__

#include <iostream>
#include <cmath>
#include "U4DBoundingVolume.h"
#include "U4DAABB.h"


namespace U4DEngine {
    
    /**
     @brief The U4DBoundingAABB represents an AABB bounding volumen entity
     */
    class U4DBoundingAABB:public U4DBoundingVolume{
      
    private:
        
        /**
         @brief Geometrical entity used for mathematical operations only
         */
        U4DAABB aabb;
        
    public:
        
        /**
         @brief Constructor of the class
         */
        U4DBoundingAABB();
        
        /**
         @brief Destructor of the class
         */
        ~U4DBoundingAABB();
       
        /**
         @brief Copy constructor
         */
        U4DBoundingAABB(const U4DBoundingAABB& value);
        
        /**
         @brief Copy constructor
         */
        U4DBoundingAABB& operator=(const U4DBoundingAABB& value);

        /**
         @brief Method which returns the maximum boundary point
         
         @return 3D point representing the maximum boundary point
         */
        U4DPoint3n getMaxBoundaryPoint();
        
        /**
         @brief Method which returns the minimum boundary point
         
         @return 3D point representing the minimum boundary point
         */
        U4DPoint3n getMinBoundaryPoint();

        /**
         @brief Method which computes a OBB bounding volume
         
         @param uHalfwidth 3D vector representing the positive halfwidth of the bounding volume. Halfwidth extends along each axis (rx,ry,rz)
         */
        void computeBoundingVolume(U4DPoint3n& uMin,U4DPoint3n& uMax);
        
    };
    
}

#endif /* defined(__UntoldEngine__U4DBoundingAABB__) */
