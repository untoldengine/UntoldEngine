//
//  U4DBoundingVolume.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/10/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DBoundingVolume__
#define __UntoldEngine__U4DBoundingVolume__

#include <iostream>
#include <vector>
#include "Constants.h"
#include <MetalKit/MetalKit.h>
#include "U4DVector3n.h"
#include "U4DIndex.h"
#include "U4DVertexData.h"
#include "U4DVisibleEntity.h"
#include "U4DPoint3n.h"

#include "U4DRenderEntity.h"

namespace U4DEngine {
    class U4DSphere;
    class U4DAABB;
}


namespace U4DEngine {

    /**
     @ingroup gameobjects
     @brief The U4DBoundingVolume class represents bounding volume entities
     */
    class U4DBoundingVolume:public U4DVisibleEntity{
      
    private:
        
        /**
         @brief set to true if the bondary volume should be renderered. Default is set to False
         */
        bool visibility;
        
    public:
        
        /**
         @brief Constructor of class
         */
        U4DBoundingVolume();
        
        /**
         @brief Destructor of class
         */
        ~U4DBoundingVolume();
        
        /**
         @brief Copy constructor
         */
        U4DBoundingVolume(const U4DBoundingVolume& value);

        /**
         @brief Copy constructor
         */
        U4DBoundingVolume& operator=(const U4DBoundingVolume& value);

        /**
         @brief Object which contains attribute data such as vertices
         */
        U4DVertexData bodyCoordinates;
        
        /**
         @brief Method which computes a spherical bounding volume
         
         @param uRadius  Radius of sphere
         @param uRings   Number of rings used for rendering
         @param uSectors Number of sectors used for rendering
         */
        virtual void computeBoundingVolume(float uRadius,int uRings, int uSectors){};
        
        /**
         @brief Method which computes a AABB bounding volume
         
         @param uMin 3D point representing the minimum coordinate point
         @param uMax 3D point representing the maximum coordinate point
         */
        virtual void computeBoundingVolume(U4DPoint3n& uMin,U4DPoint3n& uMax){};
        
        
        /**
         @brief Method which updates a AABB bounding volume
         
         @param uMin 3D point representing the minimum coordinate point
         @param uMax 3D point representing the maximum coordinate point
         */
        virtual void updateBoundingVolume(U4DPoint3n& uMin,U4DPoint3n& uMax){};
        
        /**
         @brief Method which computes a OBB bounding volume
         
         @param uHalfwidth 3D vector representing the positive halfwidth of the bounding volume. Halfwidth extends along each axis (rx,ry,rz)
         */
        virtual void computeBoundingVolume(U4DVector3n& uHalfwidth){};
        
        /**
         @brief Method which updates the state of the entity
         
         @param dt Time-step value
         */
        virtual void update(double dt){};
        
        /**
         @brief Method which sets the convex-hull vertices into a container
         
         @param uConvexHull convex-hull object containing the convex-hull vertices
         */
        virtual void setConvexHullVertices(CONVEXHULL &uConvexHull){};
        
        /**
         @brief Method which returns the convex-hull vertices
         
         @return Returns the convex-hull vertices
         */
        virtual std::vector<U4DVector3n> getConvexHullVertices(){};
        
        /**
         @brief Method which gets the support points in a particular direction
         
         @param uDirection direction to compute the support points
         
         @return Returns 3D points representing the support point in a particular direction
         */
        virtual U4DPoint3n getSupportPointInDirection(U4DVector3n& uDirection){};
        
        /**
         @brief Method which loads the attribute information needed for rendering
         */
        void loadRenderingInformation();
        
        /**
         @brief Method which updates the attribute information needed for rendering
         */
        void updateRenderingInformation();

        
        /**
         @brief Method which sets the radius for the spherical bounding volume
         
         @param uRadius Radius of sphere
         */
        virtual void setRadius(float uRadius){};
        
        /**
         @brief Method which returns the radius of the spherical bounding volume
         
         @return Returns the radius of the sphere
         */
        virtual float getRadius(){};
        
        /**
         @brief Method which returns the maximum boundary point
         
         @return 3D point representing the maximum boundary point
         */
        virtual U4DPoint3n getMaxBoundaryPoint(){};

        /**
         @brief Method which returns the minimum boundary point
         
         @return 3D point representing the minimum boundary point
         */
        virtual U4DPoint3n getMinBoundaryPoint(){};
        
        /**
         @brief Method which returns the mathematical sphere entity of the spherical boundary volume
         
         @return Returns the mathematical sphere entity
         */
        virtual U4DSphere& getSphere(){};
        
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
    
        void setLineColor(U4DVector4n &lineColor);
        
        /**
         @brief set if the engine should render the boundary volume
         
         @param uValue true to render.
         */
        void setVisibility(bool uValue);
        
        /**
         @brief get if the engine should render the boundary volume
         */
        bool getVisibility();
        
    };
    
}

#endif /* defined(__UntoldEngine__U4DBoundingVolume__) */
