//
//  U4DManifoldGeneration.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/2/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DManifoldGeneration__
#define __UntoldEngine__U4DManifoldGeneration__

#include <stdio.h>
#include "U4DCollisionDetection.h"

namespace U4DEngine {
    
    class U4DManifoldGeneration:public U4DCollisionDetection{
    private:
        
    public:
        U4DManifoldGeneration(){};
        
        ~U4DManifoldGeneration(){};
        
        virtual void determineCollisionManifold(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,std::vector<U4DSimplexStruct> uQ, U4DPoint3n& uClosestPointToOrigin){};
        
        virtual bool determineContactManifold(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,std::vector<U4DSimplexStruct> uQ, U4DPoint3n& uClosestPoint){};
        
    };
}

#endif /* defined(__UntoldEngine__U4DManifoldGeneration__) */
