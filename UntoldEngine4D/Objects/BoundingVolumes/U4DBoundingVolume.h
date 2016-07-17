//
//  U4DBoundingVolume.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/10/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DBoundingVolume__
#define __UntoldEngine__U4DBoundingVolume__

#include <iostream>
#include <vector>
#include "Constants.h"
#include "U4DOpenGLGeometry.h"
#include "U4DVector3n.h"
#include "U4DIndex.h"
#include "U4DVertexData.h"
#include "U4DVisibleEntity.h"
#include "U4DPoint3n.h"

namespace U4DEngine {
    class U4DSphere;
    class U4DAABB;
}

namespace U4DEngine {
    
    class U4DBoundingVolume:public U4DVisibleEntity{
      
    private:
        
    public:
        
       
        U4DBoundingVolume();
        
        ~U4DBoundingVolume();
        
        U4DBoundingVolume(const U4DBoundingVolume& value);

        U4DBoundingVolume& operator=(const U4DBoundingVolume& value);
        
        U4DVertexData bodyCoordinates;
        
        virtual void computeBoundingVolume(float uRadius,int uRings, int uSectors){};
        
        virtual void computeBoundingVolume(U4DPoint3n& uMin,U4DPoint3n& uMax){};
        
        virtual void computeBoundingVolume(U4DVector3n& uHalfwidth){};
        
        virtual void update(double dt){};
        
        virtual void setConvexHullVertices(CONVEXHULL &uConvexHull){};
        
        virtual std::vector<U4DVector3n> getConvexHullVertices(){};
        
        virtual U4DPoint3n getSupportPointInDirection(U4DVector3n& uDirection){};
        
        void loadRenderingInformation();
        
        void setBoundingVolumeColor(U4DVector4n& uColor);

        void draw();
        
        int determineRenderingIndex(std::vector<U4DVector3n>& uVertices, U4DVector3n& uVector, U4DVector3n& uDirection);

        virtual void setRadius(float uRadius){};
        
        virtual float getRadius(){};
        
        virtual U4DPoint3n getMaxBoundaryPoint(){};
        
        virtual U4DPoint3n getMinBoundaryPoint(){};
        
        virtual U4DSphere& getSphere(){};
        
    };
    
}

#endif /* defined(__UntoldEngine__U4DBoundingVolume__) */
