//
//  U4DCollisionAlgorithm.h
//  UntoldEngine
//
//  Created by Harold Serrano on 8/2/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DCollisionAlgorithm__
#define __UntoldEngine__U4DCollisionAlgorithm__

#include <stdio.h>
#include <vector>
#include "U4DCollisionDetection.h"
#include "U4DDynamicModel.h"

namespace U4DEngine {
    
    class U4DCollisionAlgorithm:public U4DCollisionDetection{
    
        private:
        
        public:
        
        U4DCollisionAlgorithm(){};
        
        virtual ~U4DCollisionAlgorithm(){};
        
        virtual bool collision(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,float dt){};
        
        
        virtual std::vector<U4DSimplexStruct> getCurrentSimpleStruct(){};
        
    };

}

#endif /* defined(__UntoldEngine__U4DCollisionAlgorithm__) */
