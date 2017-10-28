//
//  U4DParticleEmitterSphere.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/25/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U4DParticleEmitterSphere_hpp
#define U4DParticleEmitterSphere_hpp

#include <stdio.h>
#include "U4DParticleEmitter.h"
#include "U4DParticleSystem.h"
#include "U4DParticle.h"
#include "U4DParticleData.h"

namespace U4DEngine {
    
    class U4DParticleEmitterSphere:public U4DParticleEmitter {
        
    private:
        
    public:
        
        U4DParticleEmitterSphere();
        
        ~U4DParticleEmitterSphere();
        
        void computeVelocity(U4DParticle *uParticle);
        
    };
    
}
#endif /* U4DParticleEmitterSphere_hpp */
