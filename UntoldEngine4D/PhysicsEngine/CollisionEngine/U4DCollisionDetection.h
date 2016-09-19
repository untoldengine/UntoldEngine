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

    /**
     @brief The U4DCollisionDetection is in charge of implementing the collision detection algorithm
     */
    class U4DCollisionDetection{
        
    private:
        
    public:
       
        /**
         @brief Constructor for class
         */
        U4DCollisionDetection();
        
        /**
         @brief Destructor for class
         */
        virtual ~U4DCollisionDetection(){};

        /**
         @brief Method with returns true if a collision between two 3D entities have occurred
         
         @param uModel1 3D model entity
         @param uModel2 3D model entity
         @param dt      Time-step value
         
         @return Returns true if collision occurred
         */
        virtual bool collision(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,float dt){};
        
        /**
         @brief Method which determines the collision manifold
         
         @param uModel1 3D model entity
         @param uModel2 3D model entity
         @param uQ      Time-step value
         */
        virtual void determineCollisionManifold(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,std::vector<SIMPLEXDATA> uQ){};
        
        /**
         @brief Method which computes the supporting point in a given direction
         
         @param uBoundingVolume1 Bounding volume of a 3D model entity
         @param uBoundingVolume2 Bounding volume of a 3D model entity
         @param uDirection       3D vector direction to compute the supporting points
         
         @return Returns the supporting point as a SIMPLEXDATA object
         */
        SIMPLEXDATA calculateSupportPointInDirection(U4DBoundingVolume *uBoundingVolume1, U4DBoundingVolume* uBoundingVolume2, U4DVector3n& uDirection);
        
        /**
         @brief Method which determines the closest 3D point on a simplex to a 3D point
         
         @param uPoint 3D point to compute clostest 3D point
         @param uQ     Simplex data
         
         @return Returns 3D point closest to the simplex
         */
        U4DPoint3n determineClosestPointOnSimplexToPoint(U4DPoint3n& uPoint,std::vector<SIMPLEXDATA> uQ);
        
        /**
         @brief Method which determines the Barycentric coordinates in a Simplex
         
         @param uClosestPointToOrigin 3D point closest to the origin
         @param uQ                    Simplex data
         
         @return Returns the barycentric coordinates in a simplex
         */
        std::vector<float> determineBarycentricCoordinatesInSimplex(U4DPoint3n& uClosestPointToOrigin, std::vector<SIMPLEXDATA> uQ);
        
        
        
    };
}

#endif /* defined(__UntoldEngine__U4DCollisionDetection__) */
