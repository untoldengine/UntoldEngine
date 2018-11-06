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
 
    /**
     @ingroup particlesystem
     @brief The U4DParticleEmitterFactory class creates and allocates memory for the emitter classes such as Linear, Sphere and Torus.
     */
    class U4DParticleEmitterFactory {
        
    private:
        
    public:
        
        /**
         @brief class constructor
         */
        U4DParticleEmitterFactory();
        
        /**
         @brief class destructor
         */
        ~U4DParticleEmitterFactory();
        
        
        /**
         @brief creates the Emitters such as Linear Emitter, Sphere Emitter and Torus Emitter

         @param uParticleSystemType particle system type
         @return pointer to the Emitter object
         */
        U4DParticleEmitterInterface* createEmitter(int uParticleSystemType);
        
    };
    
}

#endif /* U4DParticleEmitterFactory_hpp */
