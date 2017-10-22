//
//  U4DParticleEmitter.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U4DParticleEmitter_hpp
#define U4DParticleEmitter_hpp

#include <stdio.h>
#include "U4DVector3n.h"

namespace U4DEngine {

    class U4DDynamicModel;

}

namespace U4DEngine {
    
    class U4DParticleEmitter {

    private:
        
        int maximimNumberOfParticles;
        
        int numberOfEmittedParticles;
        
        U4DVector3n positionVariance;
        
        U4DVector3n angleVariance;
        
        
    public:
        
        /**
         @brief document this
         */
        
        U4DParticleEmitter();
        
        ~U4DParticleEmitter();
        
        void setPositionVariance(U4DVector3n &uPosition);
        
        void setEmitAngle(U4DVector3n &uAngle);
        
        void setEmitAngleVariance(U4DVector3n &uAngle);
        
        void setSpeed(float uSpeed);
        
        void setParticlePosition(U4DDynamicModel *uParticle);
        
        void getRandomNumber();
        
    };
    
}

#endif /* U4DParticleEmitter_hpp */
