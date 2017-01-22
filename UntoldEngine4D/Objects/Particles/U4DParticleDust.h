//
//  U4DParticleDust.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/17/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef U4DParticleDust_hpp
#define U4DParticleDust_hpp

#include <stdio.h>
#include "U4DParticle.h"
#include "U4DCallback.h"
#include "U4DTimer.h"
#include "U4DVisibleEntity.h"

namespace U4DEngine {
    
    class U4DParticleDust:public U4DParticle {
        
    private:
        
        
    public:
        
        U4DCallback<U4DParticleDust> *scheduler;
        
        U4DEngine::U4DTimer *animationElapseTimer;
        
        U4DParticleDust();
        
        ~U4DParticleDust();
        
        void createParticles(float uMajorRadius, float uMinorRadius, int uParticleNumber, float uAnimationElapseTime);
        
        void animationTimer();
        
    };

}

#endif /* U4DParticleDust_hpp */
