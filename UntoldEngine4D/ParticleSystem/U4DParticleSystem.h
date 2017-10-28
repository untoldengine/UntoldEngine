//
//  U4DParticleSystem.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U4DParticleSystem_hpp
#define U4DParticleSystem_hpp

#include <stdio.h>
#include "U4DVisibleEntity.h"
#include <MetalKit/MetalKit.h>
#include "U4DRenderManager.h"
#include "U4DVertexData.h"
#include "U4DTextureData.h"
#include "U4DParticle.h"
#include "CommonProtocols.h"
#include "U4DParticleEmitterFactory.h"

namespace U4DEngine {
    class U4DParticlePhysics;
    class U4DParticleEmitterInterface;
}

namespace U4DEngine {
    
    /**
     @brief The PARTICLERENDERDATA structure holds 3D particle data
     */
    typedef struct{
        
        U4DMatrix4n absoluteSpace;
        U4DVector3n color;
        U4DVector3n startColor;
        U4DVector3n endColor;
        U4DVector3n deltaColor;
        
    }PARTICLERENDERDATA;
    
}
namespace U4DEngine {
    
    class U4DParticleSystem:public U4DVisibleEntity {
        
    private:
        
        /**
         @brief document this
         */
        int maxNumberOfParticles;
        
        /**
         @brief document this
         */
        bool hasTexture;
        
        /**
         @brief document this
         */
        U4DVector3n gravity;
        
        /**
         @brief document this
         */
        std::vector<PARTICLERENDERDATA> particleRenderDataContainer;
        
        /**
         @brief document this
         */
        std::vector<U4DParticle*> removeParticleContainer;
        
        /**
         @brief document this
         */
        U4DParticlePhysics *particlePhysics;
        
        /**
         @brief document this
         */
        U4DParticleEmitterInterface *particleEmitter;
        
        /**
         @brief document this
         */
        U4DParticleEmitterFactory emitterFactory;
        
        /**
         @brief document this
         */
        bool enableAdditiveRendering;
        
        /**
         @brief document this
         */
        bool enableNoise;
        
        /**
         @brief document this
         */
        float noiseDetail;
        
    public:
        
        U4DParticleSystem();
        
        ~U4DParticleSystem();
        
        /**
         @brief Object which contains attribute data such as vertices, and uv-coordinates
         */
        U4DVertexData bodyCoordinates;
        
        /**
         @brief Object which contains texture information
         */
        U4DTextureData textureInformation;
        
        /**
         @brief Method which starts the rendering process of the entity
         */
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        /**
         @brief Document this
         */
        void init(PARTICLESYSTEMDATA &uParticleSystemData);
        
        /**
         @brief Document this
         */
        void initParticleAttributes(float uSize);
        
        /**
         @brief Document this
         */
        void update(double dt);
        
        /**
         @brief Document this
         */
        void setMaxNumberOfParticles(int uMaxNumberOfParticles);
        
        /**
         @brief Document this
         */
        int getMaxNumberOfParticles();
        
        /**
         @brief Document this
         */
        int getNumberOfEmittedParticles();
        
        /**
         @brief document this
         */
        void setParticleTexture(const char* uTextureImage);
        
        /**
         @brief Document this
         */
        void setHasTexture(bool uValue);
        
        /**
         @brief Document this
         */
        bool getHasTexture();
        
        /**
         @brief Document this
         */
        std::vector<PARTICLERENDERDATA> getParticleRenderDataContainer();
        
        /**
         @brief Document this
         */
        void removeDeadParticle();
        
        void removeAllParticles();
        
        void initializeParticleEmitter(PARTICLESYSTEMDATA &uParticleSystemData);
        
        bool getEnableAdditiveRendering();
        
        bool getEnableNoise();
        
        float getNoiseDetail();
        
    };
    
}

#endif /* U4DParticleSystem_hpp */
