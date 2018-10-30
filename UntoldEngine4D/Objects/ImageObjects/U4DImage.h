//
//  U4DImage.h
//  UntoldEngine
//
//  Created by Harold Serrano on 8/9/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
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
 @ingroup gameobjects
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
    
    /**
     * @brief Renders the current entity
     * @details Updates the space matrix and any rendering flags. It encodes the pipeline, buffers and issues the draw command
     *
     * @param uRenderEncoder Metal encoder object for the current entity
     */
    virtual void render(id <MTLRenderCommandEncoder> uRenderEncoder);
    
    
    /**
     @brief current state of the image. Used for multi-image entities such as buttons to change between the main and secondary texture

     @return state of the image
     */
    virtual bool getImageState(){};
    
    
    /**
     @brief sets the state of the image. Used for multi-image entities such as buttons to change between the main and secondary texture

     @param uValue sets the flag to true when the image should change
     */
    virtual void setImageState(bool uValue){};
    
    
    /**
     @brief sets the image dimension

     @param uWidth width
     @param uHeight height
     */
    void setImageDimension(float uWidth,float uHeight);
    
    
    /**
     @brief sprite offset position. Used for sprite entities

     @return position offset.
     */
    virtual U4DVector2n &getSpriteOffset(){};
    
};
    
}

#endif /* defined(__UntoldEngine__U4DImage__) */
