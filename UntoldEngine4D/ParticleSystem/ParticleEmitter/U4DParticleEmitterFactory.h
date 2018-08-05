//
//  U4DParticleEmitterFactory.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/25/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DParticleEmitterFactory_hpp
#define U4DParticleEmitterFactory_hpp

#include <stdio.h>
#include "CommonProtocols.h"

namespace U4DEngine {
    class U4DParticleEmitterInterface;
    
}

namespace U4DEngine {
 
    class U4DParticleEmitterFactory {
        
    private:
        
    public:
        
        U4DParticleEmitterFactory();
        
        ~U4DParticleEmitterFactory();
        
        U4DParticleEmitterInterface* createEmitter(int uParticleSystemType);
        
    };
    
}

#endif /* U4DParticleEmitterFactory_hpp */
