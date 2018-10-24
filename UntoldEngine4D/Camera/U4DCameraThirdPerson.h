//
//  U4DCameraThirdPerson.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/21/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DCameraThirdPerson_hpp
#define U4DCameraThirdPerson_hpp

#include <stdio.h>
#include "U4DCameraInterface.h"

namespace U4DEngine {
    
    class U4DModel;
    
}

namespace U4DEngine {
    
    /**
     @ingroup camera
     @brief The U4DCameraThirdPerson class provides the camera behavior for a Third Person camera
     */
    class U4DCameraThirdPerson:public U4DCameraInterface{
        
    private:
        
        /**
         @brief Instace for the U4DCameraThirdPerson singleton
         */
        static U4DCameraThirdPerson* instance;
        
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
        
    protected:
        
        /**
         @brief Camera third person constructor
         */
        U4DCameraThirdPerson();
        
        /**
         @brief Camera third person destructor
         */
        ~U4DCameraThirdPerson();
        
    public:
        
        /**
         @brief Method which returns an instace of the U4DCameraThirdPerson singleton
         
         @return instance of the U4DCameraThirdPerson singleton
         */
        static U4DCameraThirdPerson* sharedInstance();
        
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
#endif /* U4DCameraThirdPerson_hpp */
