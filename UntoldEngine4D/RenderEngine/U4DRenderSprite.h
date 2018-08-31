//
//  U4DRenderSprite.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/23/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DRenderSprite_hpp
#define U4DRenderSprite_hpp

#include <stdio.h>
#include "U4DRenderManager.h"
#include "U4DRenderImage.h"
#include "U4DMatrix4n.h"
#include "U4DVector3n.h"
#include "U4DVector4n.h"
#include "U4DVector2n.h"
#include "U4DIndex.h"


namespace U4DEngine {
    
    /**
     * @ingroup renderingengine
     * @brief The U4DRenderSprite class manages the rendering of the sprite entities
     * 
     */
    class U4DRenderSprite:public U4DRenderImage {
        
    private:
        
        /**
         * @brief the image object the class will manage
         */
        U4DImage *u4dObject;
        
        /**
         * @brief Pointer to the sprite buffer
         */
        id<MTLBuffer> uniformSpriteBuffer;
        
    public:
        
        /**
         * @brief Constructor for class
         * @details It sets the image entity it will manage
         * 
         * @param uU4DImage image entity
         */
        U4DRenderSprite(U4DImage *uU4DImage);
        
        /**
         * @brief Destructor for the class
         */
        ~U4DRenderSprite();
        
        /**
         * @brief Loads additional information
         * @details Loads the sprite properties into the uniform buffer
         */
        void loadMTLAdditionalInformation();
        
        /**
         * @brief Renders the current entity
         * @details Updates the space matrix and any rendering flags. It encodes the pipeline, buffers and issues the draw command
         * 
         * @param uRenderEncoder Metal encoder object for the current entity
         */
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        /**
         * @brief Updates the current rendered sprite
         * @details Updates the sprite during the animation by using an offset
         */
        void updateSpriteBufferUniform();
        
    };
    
}
#endif /* U4DRenderSprite_hpp */
