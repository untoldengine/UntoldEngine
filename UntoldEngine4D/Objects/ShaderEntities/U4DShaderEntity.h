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
#include "U4DRenderEntity.h"

namespace U4DEngine {

    class U4DShaderEntity:public U4DVisibleEntity {
        
    private:
        
        std::vector<U4DVector4n> shaderParameterContainer;
        
        bool enableBlending;
        
        float shaderWidth;
        
        float shaderHeight;
        
        /**
         @brief additive rendering variable. If additive rendering is enabled, then the shaders will blend their colors among each other
         */
        bool enableAdditiveRendering;
        
        /**
         @brief Variable which contains information if the shader has textures
         */
        bool hasTexture;
        
        bool requestToHotReload;
        
        std::string hotReloadShaderFile;
        
    public:
        
        
        U4DShaderEntity(int uParamSize);
        
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
        
        void setTexture1(const char* uTexture1);

        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        void update(double dt);
        
        void updateShaderParameterContainer(int uPosition, U4DVector4n &uParamater);
        
        std::vector<U4DVector4n> getShaderParameterContainer();
        
        void setEnableBlending(bool uValue);
        
        bool getEnableBlending();
        
        float getShaderWidth();
        
        float getShaderHeight();
        
        /**
         @brief sets whether additive rendering should be enabled.
         @details If additive rendering is enabled, then the shaders will blend their colors among each other. Default is true
         
         @param uValue true or false. true means additive rendering is enabled
         */
        void setEnableAdditiveRendering(bool uValue);
        
        /**
         @brief gets whether additive rendering was enabled
         @details If additive rendering is enabled, then the shaders will blend their colors among each other

         @return true if additive rendering is enabled
         */
        bool getEnableAdditiveRendering();
        
        void setHasTexture(bool uValue);
        
        bool getHasTexture();
        
        void hotReloadShaders(std::string uFilepath);
        
    };

}


#endif /* U4DShaderEntity_hpp */
