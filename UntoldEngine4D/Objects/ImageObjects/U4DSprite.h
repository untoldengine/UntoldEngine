//
//  U4DSprite.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/27/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DSprite__
#define __UntoldEngine__U4DSprite__

#include <iostream>
#include <vector>
#include "U4DImage.h"
#include "U4DOpenGLSprite.h"
#include "U4DSpriteLoader.h"

namespace U4DEngine {
class U4DSpriteLoader;
}


namespace U4DEngine {

/**
 @brief The U4DSprite class represents sprite entities
 */
class U4DSprite:public U4DImage{
    
private:

    /**
     @brief Pointer to the sprite loader class
     */
    U4DSpriteLoader *spriteLoader;
    
public:
    
    /**
     @brief Constructor of class
     
     @param uSpriteLoader   Sprite loader object
     */
    U4DSprite(U4DSpriteLoader *uSpriteLoader);
    
    /**
     @brief Destructor of class
     */
    ~U4DSprite();
    
    /**
     @brief Name of sprite image
     */
    const char* spriteImage;
    
    /**
     @brief Method which sets a sprite
     
     @param uSprite Name of sprite image
     */
    void setSprite(const char* uSprite);
    
    /**
     @brief Method which changes the sprite
     
     @param uSprite Name of sprite image
     */
    void changeSprite(const char* uSprite);
    
    /**
     @brief Method which starts the rendering process of the entity
     */
    void draw();
};

}

#endif /* defined(__UntoldEngine__U4DSprite__) */
