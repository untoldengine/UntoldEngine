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


namespace U4DEngine {
    
    typedef struct{
        
    public:
        U4DSegment edge;
        bool tag;
        
    }Edges;
    
}


namespace U4DEngine {
    
    class U4DEPAAlgorithm:public U4DManifoldGeneration{
        
    private:
        
        
    public:
        
        U4DEPAAlgorithm(){
        };
        
        ~U4DEPAAlgorithm(){};
        
        void determineCollisionManifold(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,std::vector<SIMPLEXDATA> uQ,COLLISIONMANIFOLDONODE &uCollisionManifoldNode);
        
        void verifySimplexStructForEPA(U4DBoundingVolume *uBoundingVolume1, U4DBoundingVolume *uBoundingVolume2,std::vector<SIMPLEXDATA>& uQ);
        
        bool constructSimplexStructForSegment(U4DBoundingVolume *uBoundingVolume1, U4DBoundingVolume* uBoundingVolume2,std::vector<SIMPLEXDATA>& uQ);
        
        bool constructSimplexStructForTriangle(U4DBoundingVolume *uBoundingVolume1, U4DBoundingVolume* uBoundingVolume2,std::vector<SIMPLEXDATA>& uQ);
        
        bool determineContactManifold(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,std::vector<SIMPLEXDATA> uQ,COLLISIONMANIFOLDONODE &uCollisionManifoldNode){};
        
    };
}


#endif /* defined(__UntoldEngine__U4DEPAAlgorithm__) */
