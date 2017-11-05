//
//  U4DImage.h
//  UntoldEngine
//
//  Created by Harold Serrano on 8/9/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DImage__
#define __UntoldEngine__U4DImage__

#include <iostream>
#include "U4DVisibleEntity.h"
#include "U4DVertexData.h"
#include "U4DTextureData.h"
#include <MetalKit/MetalKit.h>
#include "U4DRenderManager.h"

namespace U4DEngine {

/**
 @brief The U4DImage class represents all images in a game
 */
class U4DImage:public U4DVisibleEntity{
  
private:
    
protected:
    
    bool imageState;
    
public:

    /**
     @brief Object which contains attribute data such as vertices, and uv-coordinates
     */
    U4DVertexData bodyCoordinates;
    
    /**
     @brief Object which contains texture information
     */
    U4DTextureData textureInformation;
    
    /**
     @brief Constructor of class
     */
    U4DImage();
    
    /**
     @brief Constructor of class
     
     @param uTextureImage   Name of texture image
     @param uWidth  Width of texture image
     @param uHeight Height of texture image
     */
    U4DImage(const char* uTextureImage,float uWidth,float uHeight);
    
    /**
     @brief Destructor of class
     */
    ~U4DImage();
   
    /**
     @brief Method which assins an image to the entity
     
     @param uTextureImage Name of texture image
     @param uWidth        Width of texture image
     @param uHeight       Height of texture image
     */
    virtual void setImage(const char* uTextureImage,float uWidth,float uHeight);
    
    virtual void render(id <MTLRenderCommandEncoder> uRenderEncoder);
    
    virtual bool getImageState(){};
    
    virtual void setImageState(bool uValue){};
    
    void setImageDimension(float uWidth,float uHeight);
    
    virtual U4DVector2n &getSpriteOffset(){};
    
};
    
}

#endif /* defined(__UntoldEngine__U4DImage__) */
