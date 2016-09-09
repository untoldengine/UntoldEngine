//
//  U4DOpenGLSprite.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/27/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DOpenGLSprite__
#define __UntoldEngine__U4DOpenGLSprite__

#include <iostream>
#include "U4DOpenGLImage.h"
#include "U4DOpenGLManager.h"

namespace U4DEngine {
  
/**
 @brief The U4DOpenGLSprite class is in charge of rendering sprite entities
 */
class U4DOpenGLSprite:public U4DOpenGLImage{
    
private:
    
    /**
     @brief Pointer representing the sprite entity
     */
    U4DImage* u4dObject;
    
public:
    
    /**
     @brief Constructor for the class
     
     @param uU4DImage It takes as a paramenter the entity representing the sprite entity
     */
    U4DOpenGLSprite(U4DImage* uU4DImage);
    
    /**
     @brief Destructor for the class
     */
    ~U4DOpenGLSprite();
    
    /**
     @brief Method which sets the image(texture) dimension found in an atlas texture
     
     @param uWidth       Image width
     @param uHeight      Image height
     @param uAtlasWidth  Atlas width
     @param uAtlasHeight Atlas height
     */
    void setImageDimension(float uWidth,float uHeight, float uAtlasWidth,float uAtlasHeight);
    
};
    
}

#endif /* defined(__UntoldEngine__U4DOpenGLSprite__) */
