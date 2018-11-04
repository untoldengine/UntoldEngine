//
//  U4DParticleEmitter.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/23/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DParticleEmitter_hpp
#define U4DParticleEmitter_hpp

#include <stdio.h>
#include "U4DParticleEmitterInterface.h"
#include "U4DParticleSystem.h"
#include "U4DParticleData.h"
#include "U4DCallback.h"
#include "U4DTimer.h"

namespace U4DEngine {
    
    /**
     @ingroup particlesystem
     @brief The U4DParticleEmitter class contains all the methods required for the computation of the position, colors and behaviors of the particles
     */
    class U4DParticleEmitter:public U4DParticleEmitterInterface {
        
    private:
    
    protected:
        
        /**
         @brief number of particles to emit
         */
        int emittedNumberOfParticles;
        
        /**
         @brief numer of particles per emission
         */
        int numberOfParticlesPerEmission;
        
        /**
         @brief emission rate of particles
         */
        float emissionRate;
        
        /**
         @brief pointer to Callback to schedule the emission rate
         */
        U4DCallback<U4DParticleEmitter> *scheduler;
        
        /**
         @brief pointer to a timer used in the callback
         */
        U4DTimer *timer;
        
        /**
         @brief pointer to the Particle System object
         */
        U4DParticleSystem *particleSystem;
        
        /**
         @brief pointer to the Particle Data object
         */
        U4DParticleData particleData;
        
        /**
         @brief variable to set whether to emit particles continuously
         */
        bool emitContinuously;
        
    public:
        
        /**
         @brief class constructor
         */
        U4DParticleEmitter();
        
        /**
         @brief class destructor
         */
        ~U4DParticleEmitter();
        
        /**
         @brief emit particles
         @details once the position, color and velocity of the particle has been computed, the particle is loaded into the particle's system scenegraph
         */
        void emitParticles();
        
        /**
         @brief Computes the velocity of the 3D particle
         
         @param uParticle pointer to the 3D particle
         */
        virtual void computeVelocity(U4DParticle *uParticle){};
        
        
        /**
         @brief compute random number
         @details used to give randomness to the computation of colors and position variance

         @param uMinValue min value
         @param uMaxValue max value
         @return random number
         */
        float getRandomNumberBetween(float uMinValue, float uMaxValue);
        
        
        /**
         @brief Computes the variance of colors

         @param uVector vector representing color change
         @param uVectorVariance desired color variance range
         */
        void computeVariance(U4DVector3n &uVector, U4DVector3n &uVectorVariance);
        
        /**
         @brief computes the position of the 3D particle
         
         @param uParticle pointer to the 3D particle
         */
        void computePosition(U4DParticle *uParticle);
        
        /**
         @brief computes the color of the 3D particle
         
         @param uParticle pointer to the 3D particle
         */
        void computeColors(U4DParticle *uParticle);
        
        /**
         @brief decreases the number of particles emitted
         @details If a particle's life is up, this method is called to update the current count of alive particles and the dead particle is removed from the scenegraph
         */
        void decreaseNumberOfEmittedParticles();
        
        /**
         @brief Gets the current number of emitted particles
         
         @return number of alive particles
         */
        int getNumberOfEmittedParticles();
        
        /**
         @brief sets the number of particles to emit per emission
         
         @param uNumberOfParticles number of particles
         */
        void setNumberOfParticlesPerEmission(int uNumberOfParticles);
        
        /**
         @brief sets the emission rate.
         @details This rate sets how often to emit particles. The lower the value, the more frequent the emision
         
         @param uEmissionRate emission rate
         */
        void setParticleEmissionRate(float uEmissionRate);
        
        /**
         @brief sets the pointer to the Particle System
         
         @param uParticleSystem pointer to particle system
         */
        void setParticleSystem(U4DParticleSystem *uParticleSystem);
        
        /**
         @brief sets the pointer to the Particle Data
         
         @param uParticleData pointer to the Particle Data
         */
        void setParticleData(U4DParticleData &uParticleData);
        
        /**
         @brief sets if the particle should emit the particles continuously
         
         @param uValue true for continuous emission, false for only one emission
         */
        void setEmitContinuously(bool uValue);
        
        
        /**
         @brief linearly interpolates between two values

         @param x Specify the start of range in which to interpolate
         @param y Specify the end of range in which to interpolate
         @param a Specify the value to use to interpolate between x and y
         @return interpolation between two values
         */
        float mix(float x, float y, float a);
    
        /**
         @brief Starts the emission of particles
         */
        void play();
        
        /**
         @brief stops the emission of particles
         */
        void stop();
        
    };
    
}

#endif /* U4DParticleEmitter_hpp */
