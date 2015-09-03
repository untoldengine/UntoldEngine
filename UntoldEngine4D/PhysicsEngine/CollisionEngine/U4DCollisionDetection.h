//
//  U4DCollisionDetection.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/2/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DCollisionDetection__
#define __UntoldEngine__U4DCollisionDetection__

#include <stdio.h>
#include <vector>
#include "U4DDynamicModel.h"

namespace U4DEngine {
    typedef struct{
        
        U4DPoint3n sa; //support point in sa
        U4DPoint3n sb; //support point in sb
        U4DPoint3n minkowskiPoint; //Minkowski difference point
        
    }U4DSimplexStruct;
    
}

namespace U4DEngine {
    
    class U4DCollisionDetection{
        
    private:
        
    public:
        U4DCollisionDetection(){};
        virtual ~U4DCollisionDetection(){};
        
        virtual bool collision(U4DStaticModel* uModel1, U4DStaticModel* uModel2,float dt){};
        virtual void determineCollisionManifold(U4DStaticModel* uModel1, U4DStaticModel* uModel2,std::vector<U4DSimplexStruct> uQ){};
        
        U4DSimplexStruct calculateSupportPointInDirection(U4DConvexPolygon *uBoundingVolume1, U4DConvexPolygon* uBoundingVolume2, U4DVector3n& uDirection);
        
        std::vector<float> determineBarycentricCoordinatesInSimplex(U4DPoint3n& uClosestPointToOrigin, std::vector<U4DSimplexStruct> uQ);
        
    };
}

#endif /* defined(__UntoldEngine__U4DCollisionDetection__) */
