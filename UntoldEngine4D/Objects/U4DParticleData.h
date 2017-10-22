//
//  U4DParticleData.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/17/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef U4DParticleData_hpp
#define U4DParticleData_hpp

#include <stdio.h>
#include "U4DVector3n.h"
#include "U4DIndex.h"
#include <vector>

namespace U4DEngine {
    
    class U4DParticleData {
        
    private:
        
    public:
        
        U4DParticleData();
        
        ~U4DParticleData();
        
        U4DVector3n color;
        
        U4DVector3n startColor;
        
        U4DVector3n endColor;
        
        U4DVector3n deltaColor;
        
        float life;
        
        bool alive;
        
    };
    
}


#endif /* U4DParticleData_hpp */
