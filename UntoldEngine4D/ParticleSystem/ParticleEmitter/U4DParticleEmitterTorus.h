//
//  U4DParticleEmitterTorus.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/25/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DParticleEmitterTorus_hpp
#define U4DParticleEmitterTorus_hpp

#include <stdio.h>
#include "U4DParticleEmitter.h"
#include "U4DParticleSystem.h"
#include "U4DParticle.h"
#include "U4DParticleData.h"

namespace U4DEngine {
    
    class U4DParticleEmitterTorus:public U4DParticleEmitter {
        
    private:
        
    public:
        
        U4DParticleEmitterTorus();
        
        ~U4DParticleEmitterTorus();
        
        void computeVelocity(U4DParticle *uParticle);
        
    };
    
}
#endif /* U4DParticleEmitterTorus_hpp */
