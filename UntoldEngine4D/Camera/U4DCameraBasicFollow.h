//
//  U4DCameraBasicFollow.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/21/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DCameraBasicFollow_hpp
#define U4DCameraBasicFollow_hpp

#include <stdio.h>
#include "U4DCameraInterface.h"
#include "U4DVector3n.h"
#include "U4DCallback.h"
#include "U4DTimer.h"

namespace U4DEngine {
    
    class U4DModel;
    class U4DBoundingAABB;
}

namespace U4DEngine {
    
    /**
     @ingroup camera
     @brief The U4DCameraBasicFollow class provides the camera behavior for a Basic Follow camera
     */
    class U4DCameraBasicFollow:public U4DCameraInterface{
        
    private:
        
        //declare the callback with the class name
        U4DEngine::U4DCallback<U4DCameraBasicFollow> *scheduler;

        //declare the timer
        U4DEngine::U4DTimer *timer;
        
        /**
         @brief Instace for the U4DCameraBasicFollow singleton
         */
        static U4DCameraBasicFollow* instance;
        
        /**
         @brief pointer to the 3D model the camera will be looking at
         */
        U4DModel *model;
        
        /**
         @brief x-distance offset
         */
        float xOffset;
        
        /**
         @brief y-distance offset
         */
        float yOffset;
        
        /**
         @brief z-distance offset. This offset represents the distance the camera is behind the 3D model
         */
        float zOffset;
        
        /**
         @brief motionAccumulator accumulates the motion of the camera using the Recency Weighted Average. Used for smoothing the camera motion.
         */
        U4DVector3n motionAccumulator;
        
        U4DVector3n previousBoundingPosition;

        U4DVector3n newBoundingPosition;
        
        bool trackBox;
        
    protected:
        
        /**
         @brief Camera basic follow constructor
         */
        U4DCameraBasicFollow();
        
        /**
         @brief Camera basic follow destructor
         */
        ~U4DCameraBasicFollow();
        
    public:
        
        U4DBoundingAABB *cameraBoundingBox;
        
        /**
         @brief Method which returns an instace of the U4DCameraBasicFollow singleton
         
         @return instance of the U4DCameraBasicFollow singleton
         */
        static U4DCameraBasicFollow* sharedInstance();
        
        /**
         @brief Updates the state of the camera behavior
         
         @param dt time-step value
         */
        void update(double dt);
        
        /**
         @brief Sets the parameters utilize by the behavior of the camera.
         
         @param uModel   3D model entity to follow
         @param uXOffset x-distance offset
         @param uYOffset y-distance offset
         @param uZOffset z-distance offset. This offset represents the distance the camera is behind the 3D model
         */
        void setParameters(U4DModel *uModel, float uXOffset, float uYOffset, float uZOffset);
        
        void setParametersWithBoxTracking(U4DModel *uModel, float uXOffset, float uYOffset, float uZOffset,U4DPoint3n uMinPoint, U4DPoint3n uMaxPoint);
        
        void trackBoundingBox();
        
        U4DBoundingAABB *getBoundingBox();
        
        void pauseBoxTracking();
        
        void resumeBoxTracking();
        
    };
    
}
#endif /* U4DCameraBasicFollow_hpp */
