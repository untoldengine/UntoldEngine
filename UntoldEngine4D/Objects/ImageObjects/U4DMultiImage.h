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
     @brief The U4DMultiImage class represents multi-images entities such as buttons with a pressed and a released image
     */
    class U4DMultiImage:public U4DImage{
        
    private:

        bool imageState;
        
        U4DRenderManager *renderManager;
        
    public:
        
        U4DEngine::U4DVertexData bodyCoordinates;
        
        U4DEngine::U4DTextureData textureInformation;
        
        /**
         @brief Constructor of class
         */
        U4DMultiImage();
        
        /**
         @brief Destructor of class
         */
        ~U4DMultiImage();
        
        
        U4DMultiImage(const char* uTextureOne,const char* uTextureTwo,float uWidth,float uHeight);
        
        virtual void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        void setImage(const char* uTextureOne,const char* uTextureTwo,float uWidth,float uHeight);
        
        bool getImageState();
        
        void setImageState(bool uValue);
        
        void changeImage();
    };

}

#endif /* defined(__UntoldEngine__U4DMultiImage__) */
