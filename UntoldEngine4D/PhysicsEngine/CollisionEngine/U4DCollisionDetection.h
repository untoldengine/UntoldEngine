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
#include "CommonProtocols.h"

namespace U4DEngine {
    
    class U4DCollisionDetection{
        
    private:
        
    public:
        U4DCollisionDetection(){};
        virtual ~U4DCollisionDetection(){};
        
        virtual bool collision(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,float dt){};
        
        
        virtual void determineCollisionManifold(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,std::vector<U4DSimplexStruct> uQ){};
        
        U4DSimplexStruct calculateSupportPointInDirection(U4DBoundingVolume *uBoundingVolume1, U4DBoundingVolume* uBoundingVolume2, U4DVector3n& uDirection);
        
        U4DPoint3n determineClosestPointOnSimplexToPoint(U4DPoint3n& uPoint,std::vector<U4DSimplexStruct> uQ);
        
        std::vector<float> determineBarycentricCoordinatesInSimplex(U4DPoint3n& uClosestPointToOrigin, std::vector<U4DSimplexStruct> uQ);
        
        
        
    };
}

#endif /* defined(__UntoldEngine__U4DCollisionDetection__) */
