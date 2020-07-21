//
//  U4DRenderMultiImage.hpp
//  MetalRendering
//
//  Created by Harold Serrano on 7/12/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DRenderMultiImage_hpp
#define U4DRenderMultiImage_hpp

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
     * @brief The U4DRenderMultiImage class manages entities with multiple images such as buttons and joysticks
     * 
     */
    class U4DRenderMultiImage:public U4DRenderImage {
        
    private:
        
        /**
         * @brief the image object the class will manage
         */
        U4DImage *u4dObject;
        
        /**
         * @brief Pointer to the buffer holding the secondary image texture
         */
        id<MTLBuffer> uniformMultiImageBuffer;
        
    public:
        
        /**
         * @brief Constructor for class
         * @details It sets the image entity it will manage
         * 
         * @param uU4DImage image entity
         */
        U4DRenderMultiImage(U4DImage *uU4DImage);
        
        /**
         * @brief Destructor for class
         * @details sets the multi-image buffer to null
         */
        ~U4DRenderMultiImage();
        
        /**
         * @brief Loads image texture into GPU
         * @details It decodes the current texture image, creates a texture object, a texture sampler, and loads the raw data into a buffer
         */
        void loadMTLTexture();
        
        /**
         * @brief Renders the current entity
         * @details Updates the space matrix and any rendering flags. It encodes the pipeline, buffers and issues the draw command
         * 
         * @param uRenderEncoder Metal encoder object for the current entity
         */
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        /**
         * @brief Sets the texture image for the image
         * @details It sets the texture that will be decoded into raw data and loaded into the texture buffer
         *
         * @param uTexture texture name
         */
        void setTexture0(const char* uTexture);
        
        /**
         * @brief Sets the texture1 image for the image
         * @details It sets the texture that will be decoded into raw data and loaded into the texture buffer
         *
         * @param uTexture texture1 name
         */
        void setTexture1(const char* uTexture);
        
        /**
         * @brief Create secondaray texture for multiple images
         * @details The main image uses the diffuse texture. The secondary image uses the ambient texture
         */
        void createSecondaryTextureObject();
        
        /**
         * @brief Loads the additional information
         * @details loads the secondary texture into the buffer
         */
        void loadMTLAdditionalInformation();
        
        /**
         * @brief Updates the image to render   
         * @details Changes the image of the entity to render
         */
        void updateMultiImage();
    };
    
}


#endif /* U4DRenderMultiImage_hpp */
