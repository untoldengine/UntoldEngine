//
//  U4DCamera.h
//  UntoldEngine
//
//  Created by Harold Serrano on 5/15/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DCamera__
#define __UntoldEngine__U4DCamera__

#include <iostream>
#include <vector>
#include "U4DEntity.h"
#include "U4DVector3n.h"
#include "U4DMatrix4n.h"
#include "U4DDualQuaternion.h"
#include "U4DCameraInterface.h"

namespace U4DEngine {
    
    class U4DMath;
    class U4DVector3n;
    class U4DMatrix4n;
    class U4DModel;
    class U4DPlane;
}

namespace U4DEngine {
    
    /**
     @ingroup camera
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
        
        /**
         @brief The camera behavior such as first person camera, third person camera, etc
         */
        U4DCameraInterface *cameraBehavior;
        
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
         @brief Gets the frustum planes of the camera. It returns six plance
         
         */
        std::vector<U4DPlane> getFrustumPlanes();
        
        /**
         @brief Updates the state of the camera
         
         @param dt time-step value
         */
        void update(double dt);
        
        /**
         @brief Set the behavior of the camera, such as third person, first person, etc

         @param uCameraBehavior Camera interface pointer to the behavior type.
         */
        void setCameraBehavior(U4DCameraInterface *uCameraBehavior);
        
    };
    
}

#endif /* defined(__UntoldEngine__U4DCamera__) */
