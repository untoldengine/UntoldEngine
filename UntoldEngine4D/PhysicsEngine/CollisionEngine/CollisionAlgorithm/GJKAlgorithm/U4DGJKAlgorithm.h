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
        
        U4DPoint3n closestPointToOrigin;
        U4DVector3n contactNormal;
        
    public:
        
        U4DGJKAlgorithm(){};
        ~U4DGJKAlgorithm(){};
        
        bool collision(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,float dt);
        
        void determineMinimumSimplexInQ(U4DPoint3n& uClosestPointToOrigin,int uNumberOfSimplexInContainer);
        
        void determineLinearCombinationOfPtInLine(U4DPoint3n& uClosestPointToOrigin);
        
        void determineLinearCombinationOfPtInTriangle(U4DPoint3n& uClosestPointToOrigin);
        
        void determineLinearCombinationOfPtInTetrahedron(U4DPoint3n& uClosestPointToOrigin);
        
        std::vector<U4DPoint3n> closestBarycentricPoints(U4DPoint3n& uClosestPointToOrigin, std::vector<U4DSimplexStruct> uQ);
        
        float distanceToCollision(U4DPoint3n& uClosestPointToOrigin, std::vector<U4DSimplexStruct> uQ);
        
        std::vector<U4DSimplexStruct> getCurrentSimpleStruct();
        
        U4DPoint3n getClosestPointToOrigin();
    };
    
}

#endif /* defined(__UntoldEngine__U4DGJKAlgorithm__) */
