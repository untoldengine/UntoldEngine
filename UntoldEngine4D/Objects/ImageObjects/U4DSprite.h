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
        
        const char * spriteAtlasImage;
        
        U4DVector2n spriteOffset;
        
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
         @brief Method which sets a sprite
         
         @param uSprite Name of sprite image
         */
        void setSprite(const char* uSprite);
        
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        void setSpriteDimension(float uSpriteWidth,float uSpriteHeight, float uAtlasWidth,float uAtlasHeight);
        
        void setSpriteOffset(U4DVector2n &uSpriteOffset);
        
        U4DVector2n &getSpriteOffset();
        
    };

}

#endif /* defined(__UntoldEngine__U4DSprite__) */
