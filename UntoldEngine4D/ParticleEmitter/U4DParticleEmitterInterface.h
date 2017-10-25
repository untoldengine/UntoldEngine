//
//  U4DParticleEmitterInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
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
    
    class U4DParticleEmitterInterface {

    private:
        
        
        
    public:
        
        /**
         @brief document this
         */
        
        U4DParticleEmitterInterface();
        
        virtual ~U4DParticleEmitterInterface();
        
        virtual void emitParticles()=0;
        
        virtual void computeVelocity(U4DParticle *uParticle)=0;
        
        virtual void computePosition(U4DParticle *uParticle)=0;
        
        virtual void computeColors(U4DParticle *uParticle)=0;
        
        virtual void decreaseNumberOfEmittedParticles()=0;
        
        virtual int getNumberOfEmittedParticles()=0;
        
        virtual void setNumberOfParticlesPerEmission(int uNumberOfParticles)=0;
        
        virtual void setParticleEmissionRate(float uEmissionRate)=0;
        
        virtual void initialize()=0;
        
        virtual void setParticleSystem(U4DParticleSystem *uParticleSystem)=0;
        
        virtual void setParticleData(U4DParticleData &uParticleData)=0;
        
        virtual void setEmitContinuously(bool uValue)=0;
        
    };
    
}

#endif /* U4DParticleEmitterInterface_hpp */
