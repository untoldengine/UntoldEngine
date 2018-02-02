//
//  U4DParticleEmitterLinear.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/23/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DParticleEmitterLinear_hpp
#define U4DParticleEmitterLinear_hpp

#include <stdio.h>
#include "U4DParticleEmitter.h"
#include "U4DParticleSystem.h"
#include "U4DParticle.h"
#include "U4DParticleData.h"

namespace U4DEngine {
    
    class U4DParticleEmitterLinear:public U4DParticleEmitter {
        
    private:
        
    public:
        
        U4DParticleEmitterLinear();
        
        ~U4DParticleEmitterLinear();
        
        void computeVelocity(U4DParticle *uParticle);
        
    };
    
}

#endif /* U4DParticleEmitterLinear_hpp */
