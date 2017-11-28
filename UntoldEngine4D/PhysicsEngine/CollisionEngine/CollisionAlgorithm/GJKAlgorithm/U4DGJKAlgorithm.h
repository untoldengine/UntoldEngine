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
        
        /**
         @brief Simplex Container
         */
        std::vector<SIMPLEXDATA> Q;
        
        /**
         @brief Closest point to the origin
         */
        U4DPoint3n closestPointToOrigin;
        
        /**
         @brief Contact Collision Normal vector
         */
        U4DVector3n contactCollisionNormal;
        
        /**
         @brief Closest collision point
         */
        U4DPoint3n closestCollisionPoint;
        
        SIMPLEXDATA vPrevious;
        
    public:
        
        /**
         @brief Constructor for the class
         */
        U4DGJKAlgorithm();
        
        /**
         @brief Destructor for the class
         */
        ~U4DGJKAlgorithm();
        
        /**
         @brief Method with returns true if a collision between two 3D entities have occurred
         
         @param uModel1 3D model entity
         @param uModel2 3D model entity
         @param dt      Time-step value
         
         @return Returns true if collision occurred
         */
        bool collision(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,float dt);
        
        /**
         @brief Method which determines the minimum Simplex in the convex-hull set Q
         
         @param uClosestPointToOrigin       Closest point to the origin
         @param uNumberOfSimplexInContainer Number of simplex in container
         */
        void determineMinimumSimplexInQ(U4DPoint3n& uClosestPointToOrigin,int uNumberOfSimplexInContainer);
        
        /**
         @brief Method which determines the linear combination of a 3D point in a 3D line
         
         @param uClosestPointToOrigin Closest point to origin
         */
        void determineLinearCombinationOfPtInLine(U4DPoint3n& uClosestPointToOrigin);
        
        /**
         @brief Method which determines the linear combination of a 3D point in a 3D triangle
         
         @param uClosestPointToOrigin Closest point to origin
         */
        void determineLinearCombinationOfPtInTriangle(U4DPoint3n& uClosestPointToOrigin);
        
        /**
         @brief Method which determines the linear combination of a 3D point in a tetrahedron
         
         @param uClosestPointToOrigin Closest point to origin
         */
        void determineLinearCombinationOfPtInTetrahedron(U4DPoint3n& uClosestPointToOrigin);
        
        /**
         @brief Method which computes the barycentric coordinates points of the collision
         
         @param uClosestPointToOrigin Closest point to origin
         @param uQ                    Simplex data
         
         @return Returns the barycentric coordinates points of the collision
         */
        std::vector<U4DPoint3n> closestBarycentricPoints(U4DPoint3n& uClosestPointToOrigin, std::vector<SIMPLEXDATA> uQ);
        
        /**
         @brief Method which computes the distance to collision
         
         @param uClosestPointToOrigin Closest point to origin
         @param uQ                    Simplex data
         
         @return Returns the distance(magnitude) to collision
         */
        float distanceToCollision(U4DPoint3n& uClosestPointToOrigin, std::vector<SIMPLEXDATA> uQ);
        
        /**
         @brief Method which returns the currect SIMPLEXDATA structure
         
         @return Returns the current SIMPLEXDATA structure
         */
        std::vector<SIMPLEXDATA> getCurrentSimpleStruct();
        
        /**
         @brief Method which returns the closest 3D point to the origin
         
         @return Returns closest 3D point to origin
         */
        U4DPoint3n getClosestPointToOrigin();
        
        /**
         @brief Method which returns the closest collision point
         
         @return Returns the closest collision point
         */
        U4DPoint3n getClosestCollisionPoint();
        
        /**
         @brief Method which returns the contact collision normal vector
         
         @return Returns the contact collision normal vector
         */
        U4DVector3n getContactCollisionNormal();
        
        bool checkGJKTerminationCondition1(SIMPLEXDATA &uV);
        
        bool checkGJKTerminationCondition2(SIMPLEXDATA &uV, SIMPLEXDATA &uP, std::vector<SIMPLEXDATA> uQ);
        
        bool checkGJKTerminationCondition3(SIMPLEXDATA &uV, SIMPLEXDATA &uP, std::vector<SIMPLEXDATA> uQ);
        
        SIMPLEXDATA getMaxSimplexInQ(std::vector<SIMPLEXDATA> uQ);
        
        /**
         @brief Method which clears all collision information
         */
        void cleanUp();
    };
    
}

#endif /* defined(__UntoldEngine__U4DGJKAlgorithm__) */
