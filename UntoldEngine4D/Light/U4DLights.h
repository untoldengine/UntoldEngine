//
//  U4DLight.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DLights__
#define __UntoldEngine__U4DLights__

#include <iostream>
#include "U4DEntity.h"

namespace U4DEngine {

    /**
     @brief The U4DLights class implements a light entity used for providing light and shadows to a game
     */
    class U4DLights:public U4DEntity{
        
    private:
        
    protected:
        
        /**
         @brief Light Constructor which sets the light position to (5.0,5.0,5.0) and its view direction to (0.0,0.0,0.0)
         */
        U4DLights();
        
        /**
         @brief Light Destructor
         */
        ~U4DLights();
        
    public:
        
        /**
         @brief Instance for U4DLights Singleton
         */
        static U4DLights* instance;
        
        /**
         @brief Method which returns an instance for the U4DLights Singleton
         
         @return Returns an instance of the U4DLights Singleton
         */
        static U4DLights* sharedInstance();
        
        /**
         @brief Method which sets the view direction of the light
         
         @param uDestinationPoint Destination point where the light should be directed
         */
        void viewInDirection(U4DVector3n& uDestinationPoint);
    };
    
}

#endif /* defined(__UntoldEngine__U4DLights__) */
