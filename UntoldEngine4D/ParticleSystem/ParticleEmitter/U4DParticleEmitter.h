//
//  U4DParticleEmitter.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/23/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
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
    
    class U4DParticleEmitter:public U4DParticleEmitterInterface {
        
    private:
    
    protected:
        
        int emittedNumberOfParticles;
        
        int numberOfParticlesPerEmission;
        
        float emissionRate;
        
        /**
         @brief document this
         */
        U4DCallback<U4DParticleEmitter> *scheduler;
        
        /**
         @brief document this
         */
        U4DTimer *timer;
        
        U4DParticleSystem *particleSystem;
        
        U4DParticleData particleData;
        
        bool emitContinuously;
        
    public:
        
        U4DParticleEmitter();
        
        ~U4DParticleEmitter();
        
        void emitParticles();
        
        virtual void computeVelocity(U4DParticle *uParticle){};
        
        float getRandomNumberBetween(float uMinValue, float uMaxValue);
        
        void computeVariance(U4DVector3n &uVector, U4DVector3n &uVectorVariance);
        
        void computePosition(U4DParticle *uParticle);
        
        void computeColors(U4DParticle *uParticle);
        
        void decreaseNumberOfEmittedParticles();
        
        int getNumberOfEmittedParticles();
        
        void setNumberOfParticlesPerEmission(int uNumberOfParticles);
        
        void setParticleEmissionRate(float uEmissionRate);
        
        void initialize();
        
        void setParticleSystem(U4DParticleSystem *uParticleSystem);
        
        void setParticleData(U4DParticleData &uParticleData);
        
        void setEmitContinuously(bool uValue);
        
        float mix(float x, float y, float a);
    
    };
    
}

#endif /* U4DParticleEmitter_hpp */
