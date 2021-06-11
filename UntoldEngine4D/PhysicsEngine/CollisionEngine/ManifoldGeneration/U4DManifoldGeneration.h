//
//  U4DManifoldGeneration.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/2/15.
//  Copyright (c) 2015 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DManifoldGeneration__
#define __UntoldEngine__U4DManifoldGeneration__

#include <stdio.h>
#include "U4DCollisionDetection.h"

namespace U4DEngine {

    /**
     @ingroup physicsengine
     @brief The U4DManifoldGeneration is in charge of computing collision maniforld information
     */
    class U4DManifoldGeneration:public U4DCollisionDetection{
    
    private:
        
    public:
    
        /**
         @brief Constructor for the class
         */
        U4DManifoldGeneration(){};
        
        /**
         @brief Destructor for the class
         */
        ~U4DManifoldGeneration(){};
        
        /**
         @brief Method which determines the collision manifold. It computes the collision planes
         
         @param uAction1                3D model entity
         @param uAction2                3D model entity
         @param uQ                     Simplex Data set
         @param uCollisionManifoldNode Collision Manifold node
         */
        virtual void determineCollisionManifold(U4DDynamicAction* uAction1, U4DDynamicAction* uAction2,std::vector<SIMPLEXDATA> uQ, COLLISIONMANIFOLDONODE &uCollisionManifoldNode){};
        
        /**
         @brief Method which determines the collision contact manifold. It retrieves the collision contact points of the collision.
         
         @param uAction1                3D model entity
         @param uAction2                3D model entity
         @param uQ                     Simplex Data set
         @param uCollisionManifoldNode Collision Manifold node
         
         @return Returns true if the collision contact points were successfully computed
         */
        virtual bool determineContactManifold(U4DDynamicAction* uAction1, U4DDynamicAction* uAction2,std::vector<SIMPLEXDATA> uQ,COLLISIONMANIFOLDONODE &uCollisionManifoldNode){};
        
    };
}

#endif /* defined(__UntoldEngine__U4DManifoldGeneration__) */
