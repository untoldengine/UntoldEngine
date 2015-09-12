//
//  U4DEPAAlgorithm.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/2/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DEPAAlgorithm__
#define __UntoldEngine__U4DEPAAlgorithm__

#include <stdio.h>
#include "U4DManifoldGeneration.h"
#include "U4DPolytope.h"

namespace U4DEngine {
    
    class U4DEPAAlgorithm:public U4DManifoldGeneration{
        
    private:
        
    public:
        
        U4DEPAAlgorithm(){};
        
        ~U4DEPAAlgorithm(){};
        
        void determineCollisionManifold(U4DStaticModel* uModel1, U4DStaticModel* uModel2, std::vector<U4DSimplexStruct> uQ);
        
        void removeAllFacesSeenByPoint(U4DPolytope& uPolytope, U4DPoint3n& uPoint);
        
        void createNewFacesToTheSimplex(U4DPolytope& uPolytope, U4DPoint3n& uPoint);
        
    };
}


#endif /* defined(__UntoldEngine__U4DEPAAlgorithm__) */
