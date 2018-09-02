//
//  U4DBoundingSphere.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/13/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DBoundingSphere__
#define __UntoldEngine__U4DBoundingSphere__

#include <iostream>
#include "U4DBoundingVolume.h"
#include "U4DSphere.h"


namespace U4DEngine {

    /**
     @ingroup gameobjects
     @brief The U4DBoundingSphere class represents a spherical bounding volumen entity
     */
    class U4DBoundingSphere:public U4DBoundingVolume{
      
    private:
       
        /**
         @brief Raidus of sphere
         */
        float radius;
        
        /**
         @brief Geometrical entity used for mathematical operations only
         */
        U4DSphere sphere;
        
    public:
        
        /**
         @brief Constructor for the class
         */
        U4DBoundingSphere();
        
        /**
         @brief Destructor for the class
         */
        ~U4DBoundingSphere();
       
        /**
         @brief Constructor for the class
         */
        U4DBoundingSphere(const U4DBoundingSphere& value);
        
        /**
         @brief Constructor for the class
         */
        U4DBoundingSphere& operator=(const U4DBoundingSphere& value);

        /**
         @brief Method which computes a spherical bounding volume
         
         @param uRadius  Radius of sphere
         @param uRings   Number of rings used for rendering
         @param uSectors Number of sectors used for rendering
         */
        void computeBoundingVolume(float uRadius,int uRings, int uSectors);
        
        /**
         @brief Method which sets the radius for the spherical bounding volume
         
         @param uRadius Radius of sphere
         */
        void setRadius(float uRadius);
        
        /**
         @brief Method which returns the radius of the spherical bounding volume
         
         @return Returns the radius of the sphere
         */
        float getRadius();
        
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
         @brief Method which returns the mathematical sphere entity of the spherical boundary volume
         
         @return Returns the mathematical sphere entity
         */
        U4DSphere& getSphere();
        
    };

}

#endif /* defined(__UntoldEngine__U4DBoundingSphere__) */
