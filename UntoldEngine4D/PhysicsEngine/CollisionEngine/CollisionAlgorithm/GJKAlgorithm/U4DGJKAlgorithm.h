//
//  U4DGJKAlgorithm.h
//  UntoldEngine
//
//  Created by Harold Serrano on 8/2/15.
//  Copyright (c) 2015 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DGJKAlgorithm__
#define __UntoldEngine__U4DGJKAlgorithm__

#include <stdio.h>
#include <vector>
#include "U4DDynamicAction.h"
#include "U4DCollisionAlgorithm.h"
#include "U4DPoint3n.h"
#include "U4DSegment.h"


namespace U4DEngine {
    
    /**
     @ingroup physicsengine
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
         
         @param uAction1 3D model entity
         @param uAction2 3D model entity
         @param dt      Time-step value
         
         @return Returns true if collision occurred
         */
        bool collision(U4DDynamicAction* uAction1, U4DDynamicAction* uAction2,float dt);
        
        /**
         @brief Method which determines the minimum Simplex in the convex-hull set Q
         
         @param uClosestPointToOrigin       Closest point to the origin
         @param uNumberOfSimplexInContainer Number of simplex in container
         
         @return Returns true if a minimum simplex was found
         */
        bool determineMinimumSimplexInQ(U4DPoint3n& uClosestPointToOrigin,int uNumberOfSimplexInContainer);
        
        /**
         @brief Method which determines the linear combination of a 3D point in a 3D line
         
         @param uClosestPointToOrigin Closest point to origin
         
         @return Returns true if a minimum simplex (line) was found
         */
        bool determineLinearCombinationOfPtInLine(U4DPoint3n& uClosestPointToOrigin);
        
        /**
         @brief Method which determines the linear combination of a 3D point in a 3D triangle
         
         @param uClosestPointToOrigin Closest point to origin
         
         @return Returns true if a minimum simplex (triangle) was found
         */
        bool determineLinearCombinationOfPtInTriangle(U4DPoint3n& uClosestPointToOrigin);
        
        /**
         @brief Method which determines the linear combination of a 3D point in a tetrahedron
         
         @param uClosestPointToOrigin Closest point to origin
         
         @return Returns true if a minimum simplex (tetrahedron) was found
         */
        bool determineLinearCombinationOfPtInTetrahedron(U4DPoint3n& uClosestPointToOrigin);
        
        /**
         @brief Method which computes the barycentric coordinates points of the collision
         
         @param uClosestPointToOrigin Closest point to origin
         @param uQ                    Simplex data
         
         @return Returns the barycentric coordinates points of the collision
         */
        std::vector<U4DPoint3n> closestBarycentricPoints(U4DPoint3n& uClosestPointToOrigin, std::vector<SIMPLEXDATA> uQ);
        
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
        
        /**
         @brief Tests termination condition: ||vPrevious||^2-||vCurrent||^2<=epsilon*||vCurrent||^2
         @param uV current simplex value
         
         @return true if termination condition is met
         */
        bool checkGJKTerminationCondition1(SIMPLEXDATA &uV);
        
        /**
         @brief Tests termination condition: ||v||^2-vdotw<=epsilon^2*||v||^2
         @param uV current simplex value
         @param uP new simplex value
         @param uQ simplex container
         
         @return true if termination condition is met
         */
        bool checkGJKTerminationCondition2(SIMPLEXDATA &uV, SIMPLEXDATA &uP, std::vector<SIMPLEXDATA> uQ);
        
        /**
         @brief Tests termination condition: ||v||^2<=epsilon*max(element in Q)
         @param uV current simplex value
         @param uP new simplex value
         @param uQ simplex container
         
         @return true if termination condition is met
         */
        bool checkGJKTerminationCondition3(SIMPLEXDATA &uV, SIMPLEXDATA &uP, std::vector<SIMPLEXDATA> uQ);
        
        /**
         @brief get maximum simplex value in container
         @param uQ simplex container
         
         @return maximum simplex
         */
        SIMPLEXDATA getMaxSimplexInQ(std::vector<SIMPLEXDATA> uQ);
        
        /**
         @brief Method which clears all collision information
         */
        void cleanUp();
    };
    
}

#endif /* defined(__UntoldEngine__U4DGJKAlgorithm__) */
