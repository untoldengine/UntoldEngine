//
//  U4DOpenGLParticleFountain.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/17/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef U4DOpenGLParticleDust_hpp
#define U4DOpenGLParticleDust_hpp

#include <stdio.h>
#include "U4DOpenGLParticle.h"
#include "U4DParticleDust.h"

namespace U4DEngine {
    
    class U4DOpenGLParticleDust:public U4DOpenGLParticle {
        
    private:
        
    public:
        
        U4DOpenGLParticleDust(U4DParticleDust* uU4DParticle);
        
        ~U4DOpenGLParticleDust();
           
    };
    
}

#endif /* U4DOpenGLParticleDust_hpp */
