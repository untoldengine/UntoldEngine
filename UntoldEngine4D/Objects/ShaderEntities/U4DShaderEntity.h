//
//  U4DShaderEntity.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/7/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DShaderEntity_hpp
#define U4DShaderEntity_hpp

#include <stdio.h>
#include "U4DVisibleEntity.h"
#include "U4DVertexData.h"
#include "U4DTextureData.h"
#include <MetalKit/MetalKit.h>
#include "U4DRenderManager.h"

namespace U4DEngine {

    class U4DShaderEntity:public U4DVisibleEntity {
        
    private:
        
        std::vector<U4DVector4n> shaderParameterContainer;
        
    public:
        
        
        U4DShaderEntity();
        
        ~U4DShaderEntity();
    
        /**
         @brief Object which contains attribute data such as vertices, and uv-coordinates
         */
        U4DVertexData bodyCoordinates;
        
        /**
         @brief Object which contains texture information
         */
        U4DTextureData textureInformation;
        
        void setShaderDimension(float uWidth,float uHeight);
        
        void setTexture0(const char* uTexture0);

        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        void updateShaderParameterContainer(int uPosition, U4DVector4n &uParamater);
        
        std::vector<U4DVector4n> getShaderParameterContainer();
        
    };

}


#endif /* U4DShaderEntity_hpp */
