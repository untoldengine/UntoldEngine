//
//  U4DParticleSystem.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/19/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
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
    
    /**
     @ingroup particlesystem
     @brief The U4DParticleSystem class is in charge of creating 3D particles
     */
    class U4DParticleSystem:public U4DVisibleEntity {
        
    private:
        
        /**
         @brief Maximum number of particles to emit
         */
        int maxNumberOfParticles;
        
        /**
         @brief Boolean variable to chech if the particle was provided with a texture
         */
        bool hasTexture;
        
        /**
         @brief particles gravity
         */
        U4DVector3n gravity;
        
        /**
         @brief vector containing 3D particle data such as position, start color, end color, etc
         */
        std::vector<PARTICLERENDERDATA> particleRenderDataContainer;
        
        /**
         @brief vector holding particles ready to be removed from the system
         */
        std::vector<U4DParticle*> removeParticleContainer;
        
        /**
         @brief pointer to the particle physics manager
         */
        U4DParticlePhysics *particlePhysics;
        
        /**
         @brief pointer to the particle emitter interface
         */
        U4DParticleEmitterInterface *particleEmitter;
        
        /**
         @brief pointer to the emitter factory, which uses the Factory Design Pattern to create the particle emitter type such as Linear, Spherical, Torus, etc
         */
        U4DParticleEmitterFactory emitterFactory;
        
        /**
         @brief additive rendering variable. If additive rendering is enabled, then the particles will blend their colors among each other
         */
        bool enableAdditiveRendering;
        
        /**
         @brief Noise boolean variable. If noise is enabled, the Perlin Noise function is used in the shaders.
         */
        bool enableNoise;
        
        /**
         @brief Amount of noise to implement. Value ranges from [1-16]. Default is 4.0
         */
        float noiseDetail;
        
    public:
        
        /**
         @brief class constructor
         */
        U4DParticleSystem();
        
        /**
         @brief class destructor
         */
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
         * @brief Renders the current entity
         * @details Updates the space matrix, any rendering flags. It encodes the pipeline, buffers and issues the draw command
         *
         * @param uRenderEncoder Metal encoder object for the current entity
         */
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        /**
         @brief Loads the particle attributes into the GPU
         @details The Particle System requires Particle System Data which informs the Particle System how to behave

         @param uModelName name of the particle
         @param uBlenderFile name of the blender file containing the attributes information
         @param uParticleSystemData Particle System Data
         @return true if the attributes were properly loaded
         */
        bool loadParticleSystem(const char* uModelName, const char* uBlenderFile, PARTICLESYSTEMDATA &uParticleSystemData);
        
        /**
         @brief Uupdates the state of the particle system
         
         @param dt Time-step value
         */
        void update(double dt);
        
        
        /**
         @brief Sets the maximum number of particles to render

         @param uMaxNumberOfParticles max number of particles
         */
        void setMaxNumberOfParticles(int uMaxNumberOfParticles);
        
        
        /**
         @brief Gets the current maximum number of particles the system will render

         @return max number of particles
         */
        int getMaxNumberOfParticles();
        
        
        /**
         @brief gets the number of emitted particles

         @return number of emitted particles
         */
        int getNumberOfEmittedParticles();
        
        
        /**
         @brief sets whether or not the particle system has a texture for the particles

         @param uValue true if texture is provided
         */
        void setHasTexture(bool uValue);
        
        
        /**
         @brief gets whether or not the particle system has a texture for the particles

         @return true if texture is provided
         */
        bool getHasTexture();
        
        
        /**
         @brief gets the vector containing the 3D particle data such as position, start color, end color, etc

         @return vector with 3D particle data
         */
        std::vector<PARTICLERENDERDATA> getParticleRenderDataContainer();
        
        
        /**
         @brief Removes dead particles
         @details Once a particle is dead, the engine removes it from its rendering process
         */
        void removeDeadParticle();
        
        /**
         @brief removes all particles
         @details The engine removes all particles from the rendering process
         */
        void removeAllParticles();
        
        /**
         @brief Initializes the particle emitter with data such as start color, end color, emition angle, speed, particle life, etc

         @param uParticleSystemData Reference to the particle system data object
         */
        void initializeParticleEmitter(PARTICLESYSTEMDATA &uParticleSystemData);
        
        
        /**
         @brief gets whether additive rendering was enabled
         @details If additive rendering is enabled, then the particles will blend their colors among each other

         @return true if additive rendering is enabled
         */
        bool getEnableAdditiveRendering();
        
        
        /**
         @brief gets if Noise was enabled
         @details Noise is created using the Perlin Noise function

         @return true if Noise is enabled
         */
        bool getEnableNoise();
        
        
        /**
         @brief gets the Noise Detail factor
         @details The higher the noise detail, the more noise is generated in the texture. Value ranges are [1,16]. Defaut is 4.0

         @return Current noise factor
         */
        float getNoiseDetail();
        
        
        /**
         @brief Initiates the emittion of particles from the particle system
         */
        void play();
        
        
        /**
         @brief Stops the emittion of particles from the particle system
         */
        void stop();
        
    };
    
}

#endif /* U4DParticleSystem_hpp */
