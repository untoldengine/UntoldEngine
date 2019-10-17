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
#include "U4DParticleLoader.h"

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
        U4DVector4n color;
        U4DVector4n startColor;
        U4DVector4n endColor;
        U4DVector4n deltaColor;
        float scaleFactor;
        float rotationAngle;
        
    }PARTICLERENDERDATA;
    
}
namespace U4DEngine {
    
    /**
     @ingroup particlesystem
     @brief The U4DParticleSystem class is in charge of creating 3D particles
     */
    class U4DParticleSystem:public U4DVisibleEntity {
        
    private:
        
        U4DParticleLoader particleLoader;
        
        /**
         @brief Maximum number of particles to emit
         */
        int maxNumberOfParticles;
        
        /**
         @brief Boolean variable to chech if the particle was provided with a texture
         */
        bool hasTexture;
        
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
        
        /**
         @brief particle system's blending source factor
         */
        int blendingFactorSource;
        
        /**
         @brief particle system's blending destination factor
         */
        int blendingFactorDest;
        
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
         @todo document this
         */
        bool loadParticleSystem(const char* uParticleAssetFile, const char* uParticleTextureFile);
        
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
         @brief sets whether additive rendering should be enabled.
         @details If additive rendering is enabled, then the particles will blend their colors among each other. Default is true
         
         @param uValue true or false. true means additive rendering is enabled
         */
        void setEnableAdditiveRendering(bool uValue);
        
        /**
         @brief gets whether additive rendering was enabled
         @details If additive rendering is enabled, then the particles will blend their colors among each other

         @return true if additive rendering is enabled
         */
        bool getEnableAdditiveRendering();
        
        /**
         @brief sets if Noise should be enabled
         @details Noise is created using the Perlin Noise function
         
         @param uValue true if Noise is enabled
         */
        void setEnableNoise(bool uValue);
        
        /**
         @brief gets if Noise was enabled
         @details Noise is created using the Perlin Noise function

         @return true if Noise is enabled
         */
        bool getEnableNoise();
        
        /**
         @brief sets the Noise Detail factor
         @details The higher the noise detail, the more noise is generated in the texture. Value ranges are [1,16]. Defaut is 4.0
         
         @param uNoiseDetail the allowed values ranges are [1,16]. Defaut is 4.0
         */
        void setNoiseDetail(float uNoiseDetail);
        
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
        
        /**
         @brief sets the particle dimension
         @param uWidth width of the particle
         @param uHeight height of the particle
         */
        void setParticleDimension(float uWidth,float uHeight);
        
        /**
         @brief returns the view direction the particle is facing
         */
        U4DVector3n getViewInDirection();
        
        /**
         @brief sets the view direction the particle should face
         @param uDestinationPoint vector to face to
         */
        void viewInDirection(U4DVector3n& uDestinationPoint);
        
        /**
         @brief gets the blending source factor
         */
        int getBlendingFactorSource();
        
        /**
         @brief gets the blending destination factor
         */
        int getBlendingFactorDest();
        
    };
    
}

#endif /* U4DParticleSystem_hpp */
