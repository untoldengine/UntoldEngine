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
    
    class U4DRenderMultiImage:public U4DRenderImage {
        
    private:
        
        U4DImage *u4dObject;
        
        //uniforms
        id<MTLBuffer> uniformMultiImageBuffer;
        
    public:
        
        U4DRenderMultiImage(U4DImage *uU4DImage);
        
        ~U4DRenderMultiImage();
        
        void loadMTLTexture();
        
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        void setDiffuseTexture(const char* uTexture);
        
        void setAmbientTexture(const char* uTexture);
        
        void createSecondaryTextureObject();
        
        void loadMTLAdditionalInformation();
        
        void updateMultiImage();
    };
    
}


#endif /* U4DRenderMultiImage_hpp */
