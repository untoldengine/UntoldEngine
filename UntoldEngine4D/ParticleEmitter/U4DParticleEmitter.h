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

namespace U4DEngine {
    
    class U4DParticleEmitter:public U4DParticleEmitterInterface {
        
    private:
    
    protected:
        
        int emittedNumberOfParticles;
        
    public:
        
        U4DParticleEmitter();
        
        ~U4DParticleEmitter();
        
        void emitParticles(U4DParticleSystem *uParticleSystem, U4DParticleData *uParticleData);
        
        virtual void computeVelocity(U4DParticle *uParticle, U4DParticleData *uParticleData){};
        
        float getRandomNumberBetween(float uMinValue, float uMaxValue);
        
        void computeVariance(U4DVector3n &uVector, U4DVector3n &uVectorVariance);
        
        void computePosition(U4DParticle *uParticle, U4DParticleSystem *uParticleSystem, U4DParticleData *uParticleData);
        
        void computeColors(U4DParticle *uParticle, U4DParticleData *uParticleData);
        
        void decreaseNumberOfEmittedParticles();
        
        int getNumberOfEmittedParticles();
        
    };
    
}

#endif /* U4DParticleEmitter_hpp */
