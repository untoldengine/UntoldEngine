//
//  U4DAABBMesh.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/15/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DAABBMesh__
#define __UntoldEngine__U4DAABBMesh__

#include <iostream>
#include <cmath>
#include "U4DMesh.h"
#include "U4DAABB.h"


namespace U4DEngine {
    
    /**
     @ingroup gameobjects
     @brief The U4DAABBMesh represents an AABB bounding volumen entity
     */
    class U4DAABBMesh:public U4DMesh{
      
    private:
        
        /**
         @brief Geometrical entity used for mathematical operations only
         */
        U4DAABB aabb;
        
    public:
        
        /**
         @brief Constructor of the class
         */
        U4DAABBMesh();
        
        /**
         @brief Destructor of the class
         */
        ~U4DAABBMesh();
       
        /**
         @brief Copy constructor
         */
        U4DAABBMesh(const U4DAABBMesh& value);
        
        /**
         @brief Copy constructor
         */
        U4DAABBMesh& operator=(const U4DAABBMesh& value);

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
        
        /**
        @brief Method which updates a AABB bounding volume
        
        @param uMin 3D point representing the minimum coordinate point
        @param uMax 3D point representing the maximum coordinate point
        */
        void updateBoundingVolume(U4DPoint3n& uMin,U4DPoint3n& uMax);
        
    };
    
}

#endif /* defined(__UntoldEngine__U4DAABBMesh__) */
