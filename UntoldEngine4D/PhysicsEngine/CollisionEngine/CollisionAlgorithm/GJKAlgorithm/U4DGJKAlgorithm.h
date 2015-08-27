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


namespace U4DEngine {
    typedef struct{
        
        U4DPoint3n sa; //support point in sa
        U4DPoint3n sb; //support point in sb
        U4DPoint3n minkowskiPoint; //Minkowski difference point
        
    }U4DSimplexStruct;
}



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
    
    /*!
     @brief  Method to detect the collision between two 3D models
     
     @param uModel1 model 1
     @param uModel2 model 2
     @param dt      time
     
     @return returns true if collision occured
     */
    bool collision(U4DStaticModel* uModel1, U4DStaticModel* uModel2,float dt);
    
    
    void determineCollisionPoints(U4DStaticModel* uModel1, U4DStaticModel* uModel2);
    
    /*!
     @brief  Method to calculate the support points (most extreme points) in a particular direction.
     
     @param uOBB1      OBB box 1
     @param uOBB2      OBB box 2
     @param uDirection Direction vector
     
     @return returns the support point of the Minkowski difference
     */
    U4DSimplexStruct calculateSupportPointInDirection(U4DConvexPolygon *uBoundingVolume1, U4DConvexPolygon* uBoundingVolume2, U4DVector3n& uDirection);
    
    /*!
     @brief  Reduce Q to the smallest subset Q' of Q such that P is in CH(Q'). That is, remove
     any points from Q not determining the subsimplex of Q in which P lies.
     
     @param uClosestPointToOrigin       closest point to origin
     @param uNumberOfSimplexInContainer number of simplex in container
     */
    void determineMinimumSimplexInQ(U4DPoint3n& uClosestPointToOrigin,int uNumberOfSimplexInContainer);
    
    void determineLinearCombinationOfPtInLine(U4DPoint3n& uClosestPointToOrigin);
    
    void determineLinearCombinationOfPtInTriangle(U4DPoint3n& uClosestPointToOrigin);
    
    void determineLinearCombinationOfPtInTetrahedron(U4DPoint3n& uClosestPointToOrigin);
    
    /**
     @brief  Determines the closest point on the simplex to a particular point
     
     @param uPoint                      Point Value
     @param uNumberOfSimplexInContainer size of simplex
     
     @return closest point on simplex with respect to uPoint
     */
    
    U4DPoint3n determineClosestPointOnSimplexToPoint(U4DPoint3n& uPoint,int uNumberOfSimplexInContainer);
    
    std::vector<float> determineBarycentricCoordinatesInSimplex(U4DPoint3n& uClosestPointToOrigin, int uNumberOfSimplexInContainer);
    
};
    
}

#endif /* defined(__UntoldEngine__U4DGJKAlgorithm__) */
