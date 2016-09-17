//
//  U4DCubeObject.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/13/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DBoundingOBB__
#define __UntoldEngine__U4DBoundingOBB__

#include <iostream>
#include "U4DBoundingVolume.h"
#include "U4DOBB.h"


namespace U4DEngine {

    /**
     @brief The U4DBoundingOBB represents an OBB bounding volumen entity
     */
    class U4DBoundingOBB:public U4DBoundingVolume{
        
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
        U4DBoundingOBB();
        
        /**
         @brief Destructor of the class
         */
        ~U4DBoundingOBB();
        
        /**
         @brief Copy constructor
         */
        U4DBoundingOBB(const U4DBoundingOBB& value);
        
        /**
         @brief Copy constructor
         */
        U4DBoundingOBB& operator=(const U4DBoundingOBB& value);

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
