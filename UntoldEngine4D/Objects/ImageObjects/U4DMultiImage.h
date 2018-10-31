//
//  U4DMultiImage.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/26/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DMultiImage__
#define __UntoldEngine__U4DMultiImage__

#include <iostream>
#include "U4DImage.h"
#include <MetalKit/MetalKit.h>
#include "U4DRenderManager.h"

namespace U4DEngine {

    /**
     @ingroup gameobjects
     @brief The U4DMultiImage class represents multi-images entities such as buttons with a pressed and a released image
     */
    class U4DMultiImage:public U4DImage{
        
    private:

        /**
         @brief variable used to change between the main and secondary texture
         */
        bool imageState;
        
        /**
         @brief pointer to the rendering manager
         */
        U4DRenderManager *renderManager;
        
    public:
        
        /**
         @brief Object which contains attribute data such as vertices, and uv-coordinates
         */
        U4DEngine::U4DVertexData bodyCoordinates;
        
        /**
         @brief Object which contains texture information
         */
        U4DEngine::U4DTextureData textureInformation;
        
        /**
         @brief Constructor of class
         */
        U4DMultiImage();
        
        /**
         @brief Destructor of class
         */
        ~U4DMultiImage();
        
        /**
         @brief Constructor of class
         
         @param uTextureOne main texture image
         @param uTextureTwo secondary texture image
         @param uWidth width of texture
         @param uHeight height of texture
         */
        U4DMultiImage(const char* uTextureOne,const char* uTextureTwo,float uWidth,float uHeight);
        
        /**
         * @brief Renders the current entity
         * @details Updates the space matrix and any rendering flags. It encodes the pipeline, buffers and issues the draw command
         *
         * @param uRenderEncoder Metal encoder object for the current entity
         */
        virtual void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        
        /**
         @brief sets the image textures

         @param uTextureOne main texture image
         @param uTextureTwo secondary texture image
         @param uWidth width of texture
         @param uHeight height of texture
         */
        void setImage(const char* uTextureOne,const char* uTextureTwo,float uWidth,float uHeight);
        
        /**
         @brief current state of the image. Used for multi-image entities such as buttons to change between the main and secondary texture
         
         @return state of the image
         */
        bool getImageState();
        
        /**
         @brief sets the state of the image. Used for multi-image entities such as buttons to change between the main and secondary texture
         
         @param uValue sets the flag to true when the image should change
         */
        void setImageState(bool uValue);
        
        
        /**
         @brief change the current rendered texture. It alternates between the main and secondary texture
         */
        void changeImage();
    };

}

#endif /* defined(__UntoldEngine__U4DMultiImage__) */
