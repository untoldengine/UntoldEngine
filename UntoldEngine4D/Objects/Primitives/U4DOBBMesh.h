//
//  U4DCubeObject.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/13/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DOBBMesh__
#define __UntoldEngine__U4DOBBMesh__

#include <iostream>
#include "U4DMesh.h"
#include "U4DOBB.h"


namespace U4DEngine {

    /**
     @ingroup gameobjects
     @brief The U4DOBBMesh represents an OBB bounding volumen entity
     */
    class U4DOBBMesh:public U4DMesh{
        
    private:
       
        /**
         @brief Positive halfwidth. Extents of OBB along each axis
         */
        U4DVector3n halfwidth;
        
        /**
         @brief Geometrical entity used for mathematical operations only
         */
        U4DOBB obb;
        
    public:

        /**
         @brief Constructor of the class
         */
        U4DOBBMesh();
        
        /**
         @brief Destructor of the class
         */
        ~U4DOBBMesh();
        
        /**
         @brief Copy constructor
         */
        U4DOBBMesh(const U4DOBBMesh& value);
        
        /**
         @brief Copy constructor
         */
        U4DOBBMesh& operator=(const U4DOBBMesh& value);

        /**
         @brief Method which computes a AABB bounding volume
         
         @param uMin 3D point representing the minimum coordinate point
         @param uMax 3D point representing the maximum coordinate point
         */
        void computeBoundingVolume(U4DVector3n& uHalfwidth);
      
        /**
         @brief Method which sets the haldwidth for the OBB
         
         @param uHalfwidth 3D vector holding the positive x,y, and z half-lenghts of the OBB
         */
        void setHalfwidth(U4DVector3n& uHalfwidth);
        
    };
    
}

#endif /* defined(__UntoldEngine__U4DCubeObject__) */
