//
//  U4DGJKAlgorithm.h
//  UntoldEngine
//
//  Created by Harold Serrano on 8/2/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DGJKAlgorithm__
#define __UntoldEngine__U4DGJKAlgorithm__

#include <stdio.h>
#include <vector>
#include "U4DDynamicModel.h"
#include "U4DCollisionAlgorithm.h"
#include "U4DPoint3n.h"
#include "U4DSegment.h"


namespace U4DEngine {
    
    /**
     @brief The U4DGJKAlgorithm class implements the Gilbert-Johnson-keerthi algorithm for collision detection.

     */
    class U4DGJKAlgorithm:public U4DCollisionAlgorithm{
        
    private:
        
        std::vector<U4DSimplexStruct> Q; //simplex container
        
    public:
        
        U4DGJKAlgorithm(){};
        ~U4DGJKAlgorithm(){};
        
        bool collision(U4DStaticModel* uModel1, U4DStaticModel* uModel2,float dt);
        
        void determineMinimumSimplexInQ(U4DPoint3n& uClosestPointToOrigin,int uNumberOfSimplexInContainer);
        
        void determineLinearCombinationOfPtInLine(U4DPoint3n& uClosestPointToOrigin);
        
        void determineLinearCombinationOfPtInTriangle(U4DPoint3n& uClosestPointToOrigin);
        
        void determineLinearCombinationOfPtInTetrahedron(U4DPoint3n& uClosestPointToOrigin);
        
        U4DPoint3n determineClosestPointOnSimplexToPoint(U4DPoint3n& uPoint,int uNumberOfSimplexInContainer);
        
        void determineCollisionPoints(U4DStaticModel* uModel1, U4DStaticModel* uModel2, std::vector<U4DSimplexStruct> uQ);
        
        std::vector<U4DSimplexStruct> getCurrentSimpleStruct();
        
    };
    
}

#endif /* defined(__UntoldEngine__U4DGJKAlgorithm__) */
