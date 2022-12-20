//
//  U4DSphereMesh.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/13/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DSphereMesh__
#define __UntoldEngine__U4DSphereMesh__

#include <iostream>
#include "U4DMesh.h"
#include "U4DSphere.h"


namespace U4DEngine {

    /**
     @ingroup gameobjects
     @brief The U4DSphereMesh class represents a spherical bounding volumen entity
     */
    class U4DSphereMesh:public U4DMesh{
      
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
        U4DSphereMesh();
        
        /**
         @brief Destructor for the class
         */
        ~U4DSphereMesh();
       
        /**
         @brief Constructor for the class
         */
        U4DSphereMesh(const U4DSphereMesh& value);
        
        /**
         @brief Constructor for the class
         */
        U4DSphereMesh& operator=(const U4DSphereMesh& value);

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

#endif /* defined(__UntoldEngine__U4DSphereMesh__) */
