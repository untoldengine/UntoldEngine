//
//  U4DSprite.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/27/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
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
     @ingroup gameobjects
     @brief The U4DSprite class represents sprite entities
     */
    class U4DSprite:public U4DImage{
        
    private:

        /**
         @brief Pointer to the sprite loader class
         */
        U4DSpriteLoader *spriteLoader;
        
        /**
         @brief name of the sprite atlas texture
         */
        const char * spriteAtlasImage;
        
        /**
         @brief sprite position offset
         */
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
         @brief Sets a sprite with a texture
         
         @param uSprite Name of sprite image
         */
        void setSprite(const char* uSprite);
        
        /**
         @brief Update sprite
         
         @param uSprit Name of sprite image
         */
        void updateSprite(const char* uSprite);
        
        /**
         * @brief Renders the current entity
         * @details Updates the space matrix and any rendering flags. It encodes the pipeline, buffers and issues the draw command
         *
         * @param uRenderEncoder Metal encoder object for the current entity
         */
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        
        /**
         @brief sets the sprite dimension

         @param uSpriteWidth sprite image width
         @param uSpriteHeight sprite image height
         @param uAtlasWidth sprite atlas width
         @param uAtlasHeight sprite atlas height
         */
        void setSpriteDimension(float uSpriteWidth,float uSpriteHeight, float uAtlasWidth,float uAtlasHeight);
        
        
        /**
         @brief sets the offset position for the sprite

         @param uSpriteOffset offset position
         */
        void setSpriteOffset(U4DVector2n &uSpriteOffset);
        
        /**
         @brief sprite offset position. Used for sprite entities
         
         @return position offset.
         */
        U4DVector2n &getSpriteOffset();
        
    };

}

#endif /* defined(__UntoldEngine__U4DSprite__) */
