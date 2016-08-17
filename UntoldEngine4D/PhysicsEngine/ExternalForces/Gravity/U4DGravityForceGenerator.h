//
//  GravityForceGenerator.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/23/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DGravityForceGenerator__
#define __UntoldEngine__U4DGravityForceGenerator__

#include <iostream>
#include "U4DEntityManager.h"
#include "U4DBodyForceGenerator.h"


namespace U4DEngine {
    
    class U4DVector3n;
    class U4DDynamicModel;
    
}

namespace U4DEngine {
    
    class U4DGravityForceGenerator:public U4DBodyForceGenerator{
      
    private:
        
    public:
        
        U4DGravityForceGenerator();
        
        ~U4DGravityForceGenerator();
        
        void updateForce(U4DDynamicModel *uModel, float dt);

    };
        
}

#endif /* defined(__UntoldEngine__GravityForceGenerator__) */
