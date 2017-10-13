//
//  U4DParticle.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/10/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U4DParticle_hpp
#define U4DParticle_hpp

#include <stdio.h>
#include "U4DVisibleEntity.h"
#include <MetalKit/MetalKit.h>
#include "U4DRenderManager.h"
#include "U4DVertexData.h"
#include "U4DTextureData.h"
#include "U4DParticleData.h"

namespace U4DEngine {
    
    class U4DParticle:public U4DVisibleEntity {
        
    private:
        
    protected:
        
        /**
         @brief document this
         */
        int numberOfParticles;
        
        /**
         @brief document this
         */
        float particleAnimationElapsedTime;
        
        /**
         @brief document this
         */
        U4DVector4n diffuseColor;
        
        /**
         @brief document this
         */
        bool hasTexture;
        
        /**
         @brief document this
         */
        int particleLifeTime;
        
    public:
        
        /**
         @brief Object which contains attribute data such as vertices, and uv-coordinates
         */
        U4DVertexData bodyCoordinates;
        
        /**
         @brief Object which contains particle data such as particle velocity
         */
        U4DParticleData particleData;
        
        /**
         @brief Object which contains texture information
         */
        U4DTextureData textureInformation;
        
        /**
         @brief Constructor of class
         */
        U4DParticle();
        
        /**
         @brief Destructor of class
         */
        ~U4DParticle();
        
        /**
         @brief Method which starts the rendering process of the entity
         */
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        /**
         @brief Document this
         */
        void setNumberOfParticles(int uNumberOfParticles);
        
        /**
         @brief Document this
         */
        int getNumberOfParticles();
        
        /**
         @brief Document this
         */
        void setParticlesVertices();
        
        /**
         @brief document this
         */
        void setParticleTexture(const char* uTextureImage);
        
        /**
         @brief document this
         */
        virtual void createParticles(float uMajorRadius, float uMinorRadius, int uNumberOfParticles, float uAnimationDelay, const char *uTexture){};
        
        /**
         @brief document this
         */
        void particleAnimationTimer();
        
        /**
         @brief document this
         */
        float getParticleAnimationElapsedTime();
        
        void setDiffuseColor(U4DVector4n &uDiffuseColor);
        
        U4DVector4n getDiffuseColor();
        
        void setHasTexture(bool uValue);
        
        bool getHasTexture();
        
        void setParticleLifetime(int uLifetime);
        
        int getParticleLifetime();
        
    };
    
}
#endif /* U4DParticle_hpp */
