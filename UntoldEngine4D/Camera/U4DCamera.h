//
//  U4DCamera.h
//  UntoldEngine
//
//  Created by Harold Serrano on 5/15/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DCamera__
#define __UntoldEngine__U4DCamera__

#include <iostream>
#include <vector>
#include "U4DEntity.h"
#include "U4DVector3n.h"
#include "U4DMatrix4n.h"
#include "U4DDualQuaternion.h"

namespace U4DEngine {
    
    class U4DMath;
    class U4DVector3n;
    class U4DMatrix4n;
    class U4DModel;
    class U4DPlane;
}

namespace U4DEngine {
    
    /**
     @brief The U4DCamera class is in charge of implementing a camera entity for the engine
     */
    class U4DCamera:public U4DEntity{
      
    private:
        
        /**
         @brief Camera Perspective projection view space
         */
        U4DMatrix4n perspectiveView;
        
        /**
         @brief Camera Orthographic projection view space
         */
        U4DMatrix4n orthographicView;
        
        /**
         @brief Instace for the U4DCamera singleton
         */
        static U4DCamera* instance;
        
    protected:
        
        /**
         @brief Camera constructor
         */
         U4DCamera();
        
        /**
         @brief Camera destructor
         */
        ~U4DCamera();
        
    public:

        /**
         @brief Method which returns an instace of the U4DCamera singleton
         
         @return instance of the U4DCamera singleton
         */
        static U4DCamera* sharedInstance();
        
        /**
         @brief Method which assigns the camera entity to follow a 3D model entity
         
         @param uModel   3D model entity to follow
         @param uXOffset x-distance offset
         @param uYOffset y-distance offset
         @param uZOffset z-distance offset
         */
        void followModel(U4DModel *uModel, float uXOffset, float uYOffset, float uZOffset);
        
        /**
         @brief Method which returns the current view-direction of the camera
         
         @return Returns a vector representing the view-direction of the camera
         */
        U4DVector3n getViewInDirection();
        
        /**
         @brief Method which sets the view-direction of the camera
         
         @param uDestinationPoint Destination point where the camera should be looking at.
         */
        void viewInDirection(U4DVector3n& uDestinationPoint);
        
        /**
         @todo document this. it gets the frustum planes
         
         */
        std::vector<U4DPlane> getFrustumPlanes();
    };
    
}

#endif /* defined(__UntoldEngine__U4DCamera__) */
