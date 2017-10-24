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
#include "U4DParticleData.h"
#include "U4DParticle.h"
#include "CommonProtocols.h"
#include "U4DCallback.h"
#include "U4DTimer.h"

namespace U4DEngine {
    class U4DParticlePhysics;
    class U4DParticleEmitterInterface;
    class U4DParticleData;
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
        U4DCallback<U4DParticleSystem> *scheduler;
        
        /**
         @brief document this
         */
        U4DTimer *timer;
        
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
        U4DParticleData *particleData;
        
    public:
        
        U4DParticleSystem(U4DParticleEmitterInterface *uParticleEmitter, U4DParticleData *uParticleData);
        
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
        void init();
        
        /**
         @brief Document this
         */
        void initParticleAttributes();
        
        /**
         @brief Document this
         */
        void loadParticles();
        
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
        
    };
    
}

#endif /* U4DParticleSystem_hpp */
