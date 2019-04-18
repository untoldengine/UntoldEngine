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

namespace U4DEngine {
    
    class U4DModel;
    
}

namespace U4DEngine {
    
    /**
     @ingroup camera
     @brief The U4DCameraBasicFollow class provides the camera behavior for a Basic Follow camera
     */
    class U4DCameraBasicFollow:public U4DCameraInterface{
        
    private:
        
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
        
    };
    
}
#endif /* U4DCameraBasicFollow_hpp */
