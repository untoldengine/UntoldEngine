//
//  U4DLight.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/14.
//  Copyright (c) 2014 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DDirectionalLight__
#define __UntoldEngine__U4DDirectionalLight__

#include <iostream>
#include "U4DEntity.h"

namespace U4DEngine {

    /**
     @ingroup light
     @brief The U4DDirectionalLight class implements a light entity used for providing light and shadows to a game
     */
    class U4DDirectionalLight: public U4DEntity{
        
    private:
        
        /**
         @brief The diffuse color of the light
         */
        U4DVector3n diffuseColor;
        
        /**
         @brief The specular color of the light
         */
        U4DVector3n specularColor;
        
        
        static U4DDirectionalLight* instance;
        
    protected:
        
        /**
         @brief Light Constructor which sets the light position to (5.0,5.0,5.0) and its view direction to (0.0,0.0,0.0)
         */
        U4DDirectionalLight();
        
        /**
         @brief Light Destructor
         */
        ~U4DDirectionalLight();
        
    public:
        
        /**
         @brief Method which returns an instance for the U4DDirectionalLight Singleton
         
         @return Returns an instance of the U4DDirectionalLight Singleton
         */
        static U4DDirectionalLight* sharedInstance();
        
        /**
         @brief Method which sets the view direction of the light
         
         @param uDestinationPoint Destination point where the light should be directed
         */
        void viewInDirection(U4DVector3n& uDestinationPoint);
        
        
        /**
         @brief Gets the view direction of the light.

         @return Returns the view direction. Note that the coordinate space for the light is different due to its implementation. +z points outward. -z points inward into the screen.
         */
        U4DVector3n getViewInDirection();
        
        
        /**
         @brief Sets the diffuse color for the light

         @param uDiffuseColor diffuse color in vector format
         */
        void setDiffuseColor(U4DVector3n &uDiffuseColor);
        
        
        /**
         @brief Sets the specular color for the light

         @param uSpecularColor specular color in vector format
         */
        void setSpecularColor(U4DVector3n &uSpecularColor);
        
        /**
         @brief gets the light diffuse color

         @return diffuse color in vector format
         */
        U4DVector3n getDiffuseColor();
        
        
        /**
         @brief gets the light specular color

         @return specular color in vector format
         */
        U4DVector3n getSpecularColor();
        
    };
    
}

#endif /* defined(__UntoldEngine__U4DDirectionalLight__) */
