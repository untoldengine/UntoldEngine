//
//  U4DLight.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/14.
//  Copyright (c) 2014 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DLights__
#define __UntoldEngine__U4DLights__

#include <iostream>
#include "U4DMatrix4n.h"
#include "U4DVector3n.h"
#include "U4DVector2n.h"
#include "U4DIndex.h"
#include "U4DVertexData.h"
#include "U4DRenderEntity.h"
#include "U4DVisibleEntity.h"

namespace U4DEngine {

    /**
     @ingroup light
     @brief The U4DLights class implements a light entity used for providing light and shadows to a game
     */
    class U4DLights:public U4DVisibleEntity{
        
    private:
        
        /**
         @brief The diffuse color of the light
         */
        U4DVector3n diffuseColor;
        
        /**
         @brief The specular color of the light
         */
        U4DVector3n specularColor;
        
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
        
        U4DVertexData bodyCoordinates;
        
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
        
        
        /**
         @brief Gets the view direction of the light.

         @return Returns the view direction. Note that the coordinate space for the light is different due to its implementation. +z points outward. -z points inward into the screen.
         */
        U4DVector3n getViewInDirection();
        
        
        /**
         @brief Computes the light volume which determines the vertices for the light shape (a small cube)

         @param uMin min points for the cube
         @param uMax max points for the cube
         */
        void computeLightVolume(U4DPoint3n& uMin,U4DPoint3n& uMax);
        
        /**
         * @brief Renders the current Light entity
         * @details Updates the space matrix and any rendering flags. It encodes the pipeline, buffers and issues the draw command
         *
         * @param uRenderEncoder Metal encoder object for the current entity
         */
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        
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

#endif /* defined(__UntoldEngine__U4DLights__) */
