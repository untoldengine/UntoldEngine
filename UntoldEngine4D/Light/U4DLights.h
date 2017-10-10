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
#include "U4DMatrix4n.h"
#include "U4DVector3n.h"
#include "U4DVector2n.h"
#include "U4DIndex.h"
#include "U4DVertexData.h"
#include "U4DRenderManager.h"
#include "U4DVisibleEntity.h"

namespace U4DEngine {

    /**
     @brief The U4DLights class implements a light entity used for providing light and shadows to a game
     */
    class U4DLights:public U4DVisibleEntity{
        
    private:
        
        U4DRenderManager *renderManager;
        
        U4DVector3n diffuseColor;
        
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
        
        U4DVector3n getViewInDirection();
        
        void computeLightVolume(U4DPoint3n& uMin,U4DPoint3n& uMax);
        
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        void setDiffuseColor(U4DVector3n &uDiffuseColor);
        
        void setSpecularColor(U4DVector3n &uSpecularColor);
        
        U4DVector3n getDiffuseColor();
        
        U4DVector3n getSpecularColor();
        
    };
    
}

#endif /* defined(__UntoldEngine__U4DLights__) */
