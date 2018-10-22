//
//  U4DCameraFirstPerson.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/21/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DCameraFirstPerson_hpp
#define U4DCameraFirstPerson_hpp

#include <stdio.h>
#include "U4DCameraInterface.h"

namespace U4DEngine {
    
    class U4DModel;
    
}

namespace U4DEngine {
    
    /**
     @ingroup camera
     @brief The U4DCameraFirstPerson class provides the camera behavior for a First Person camera
     */
    class U4DCameraFirstPerson:public U4DCameraInterface{
        
    private:
        
        /**
         @brief Instace for the U4DCameraFirstPerson singleton
         */
        static U4DCameraFirstPerson* instance;
        
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
         @brief z-distance offset. This offset represents the distance the camera is ahead the 3D model
         */
        float zOffset;
        
    protected:
        
        /**
         @brief Camera first person constructor
         */
        U4DCameraFirstPerson();
        
        /**
         @brief Camera first person destructor
         */
        ~U4DCameraFirstPerson();
        
    public:
        
        /**
         @brief Method which returns an instace of the U4DCameraFirstPerson singleton
         
         @return instance of the U4DCameraFirstPerson singleton
         */
        static U4DCameraFirstPerson* sharedInstance();
        
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
         @param uZOffset z-distance offset. This offset represents the distance the camera is ahead the 3D model
         */
        void setParameters(U4DModel *uModel, float uXOffset, float uYOffset, float uZOffset);
        
    };
    
}
#endif /* U4DCameraFirstPerson_hpp */
