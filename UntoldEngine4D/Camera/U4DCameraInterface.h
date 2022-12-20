//
//  U4DCameraInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/21/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DCameraInterface_hpp
#define U4DCameraInterface_hpp

#include <stdio.h>
#include "U4DPoint3n.h"

namespace U4DEngine {

    class U4DModel;
    class U4DAABBMesh;
}

namespace U4DEngine {
    
    /**
     @ingroup camera
     @brief The U4DCameraInterface provides the interface for the camera behaviors (first person camera, third person camera, etc)
     */
    class U4DCameraInterface{
        
    private:
        
        
    public:
        
        /**
         * @brief Virtual destructor for interface. The actual destructor implementation is set by the subclasses
         */
        virtual ~U4DCameraInterface(){};
        
        /**
         @brief Updates the state of the camera behavior
         
         @param dt time-step value
         */
        virtual void update(double dt)=0;
        
        /**
         @brief Sets the parameters utilize by the behavior of the camera.
         
         @param uModel   3D model entity to follow
         @param uXOffset x-distance offset
         @param uYOffset y-distance offset
         @param uZOffset z-distance offset
         */
        virtual void setParameters(U4DModel *uModel, float uXOffset, float uYOffset, float uZOffset)=0;
        
        virtual void setParametersWithBoxTracking(U4DModel *uModel, float uXOffset, float uYOffset, float uZOffset,U4DPoint3n uMinPoint, U4DPoint3n uMaxPoint)=0;

        virtual void trackBoundingBox()=0;
        
        virtual U4DAABBMesh *getBoundingBox()=0;
        
        virtual void pauseBoxTracking()=0;
        
        virtual void resumeBoxTracking()=0;
        
        
    };
    
}

#endif /* U4DCameraInterface_hpp */
