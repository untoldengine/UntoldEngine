//
//  U4DParticleEmitterInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/19/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DParticleEmitterInterface_hpp
#define U4DParticleEmitterInterface_hpp

#include <stdio.h>
#include "U4DVector3n.h"

namespace U4DEngine {

    class U4DParticleSystem;
    class U4DParticleData;
    class U4DParticle;
}

namespace U4DEngine {
    
    /**
     @ingroup particlesystem
     @brief The U4DParticleEmitterInterface interface contains all the methods required for the computation of the position, colors and behaviors of the particles
     */
    class U4DParticleEmitterInterface {

    private:
        
    public:
        
        /**
         @brief interface destructor
         */
        virtual ~U4DParticleEmitterInterface(){};
        
        
        /**
         @brief emit particles
         @details once the position, color and velocity of the particle has been computed, the particle is loaded into the particle's system scenegraph
         */
        virtual void emitParticles()=0;
        
        
        /**
         @brief Computes the velocity of the 3D particle

         @param uParticle pointer to the 3D particle
         */
        virtual void computeVelocity(U4DParticle *uParticle)=0;
        
        
        /**
         @brief computes the position of the 3D particle

         @param uParticle pointer to the 3D particle
         */
        virtual void computePosition(U4DParticle *uParticle)=0;
        
        
        /**
         @brief computes the color of the 3D particle

         @param uParticle pointer to the 3D particle
         */
        virtual void computeColors(U4DParticle *uParticle)=0;
        
        /**
         @brief computes the radial acceleration of the 3D particle
         
         @param uParticle pointer to the 3D particle
         */
        virtual void computeRadialAcceleration(U4DParticle *uParticle)=0;
        
        /**
         @brief computes the tangential acceleration of the 3D particle
         
         @param uParticle pointer to the 3D particle
         */
        virtual void computeTangentialAcceleration(U4DParticle *uParticle)=0;
        
        
        /**
         @brief decreases the number of particles emitted
         @details If a particle's life is up, this method is called to update the current count of alive particles and the dead particle is removed from the scenegraph
         */
        virtual void decreaseNumberOfEmittedParticles()=0;
        
        
        /**
         @brief Gets the current number of emitted particles

         @return number of alive particles
         */
        virtual int getNumberOfEmittedParticles()=0;
        
        
        /**
         @brief sets the number of particles to emit per emission

         @param uNumberOfParticles number of particles
         */
        virtual void setNumberOfParticlesPerEmission(int uNumberOfParticles)=0;
        
        
        /**
         @brief sets the emission rate.
         @details This rate sets how often to emit particles. The lower the value, the more frequent the emision

         @param uEmissionRate emission rate
         */
        virtual void setParticleEmissionRate(float uEmissionRate)=0;
        
        
        /**
         @brief sets the pointer to the Particle System

         @param uParticleSystem pointer to particle system
         */
        virtual void setParticleSystem(U4DParticleSystem *uParticleSystem)=0;
        
        
        /**
         @brief sets the pointer to the Particle Data

         @param uParticleData pointer to the Particle Data
         */
        virtual void setParticleData(U4DParticleData &uParticleData)=0;
        
        
        /**
         @brief sets if the particle should emit the particles continuously

         @param uValue true for continuous emission, false for only one emission
         */
        virtual void setEmitContinuously(bool uValue)=0;
        
        
        /**
         @brief Starts the emission of particles
         */
        virtual void play()=0;
        
        
        /**
         @brief stops the emission of particles
         */
        virtual void stop()=0;
        
        /**
         @brief sets the emitter duration rate
         @param uEmitterDurationRate emitter duration rate
         */
        virtual void setEmitterDurationRate(float uEmitterDurationRate)=0;
        
        /**
         @brief computes the scale of the 3D particle
         
         @param uParticle pointer to the 3D particle
         */
        virtual void computeScale(U4DParticle *uParticle)=0;
        
        /**
         @brief computes the rotation of the 3D particle
         
         @param uParticle pointer to the 3D particle
         */
        virtual void computeRotation(U4DParticle *uParticle)=0;
        
        
    };
    
}

#endif /* U4DParticleEmitterInterface_hpp */
