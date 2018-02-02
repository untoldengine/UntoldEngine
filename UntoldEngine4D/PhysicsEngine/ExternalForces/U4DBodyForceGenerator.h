//
//  BodyForceGenerator.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/23/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DBodyForceGenerator__
#define __UntoldEngine__U4DBodyForceGenerator__

#include <iostream>
#include "U4DDynamicModel.h"

namespace U4DEngine {
    
    class U4DDynamicModel;
    
}

namespace U4DEngine {

    /**
     @brief The U4DBodyForceGenerator class is in charge of updating all external forces acting on a 3D entity
     */
    class U4DBodyForceGenerator{
        
    public:
        
        virtual void updateForce(U4DDynamicModel *uModel, float dt)=0;
        
    };
    
}

#endif /* defined(__UntoldEngine__BodyForceGenerator__) */
