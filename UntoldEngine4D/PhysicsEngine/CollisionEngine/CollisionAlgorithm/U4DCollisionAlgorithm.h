//
//  U4DCollisionAlgorithm.h
//  UntoldEngine
//
//  Created by Harold Serrano on 8/2/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DCollisionAlgorithm__
#define __UntoldEngine__U4DCollisionAlgorithm__

#include <stdio.h>
#include <vector>
#include "U4DCollisionDetection.h"
#include "U4DDynamicModel.h"


namespace U4DEngine {

    /**
     @brief The 4DCollisionAlgorithm is a virtual class in charge of implementing the algorithm used during a collision
     */
    class U4DCollisionAlgorithm:public U4DCollisionDetection{
    
        private:
            
        public:
       
        /**
         @brief Constructor for the class
         */
        U4DCollisionAlgorithm(){};
        
        /**
         @brief Destructor for the class
         */
        virtual ~U4DCollisionAlgorithm(){};

        /**
         @brief Method with returns true if a collision between two 3D entities have occurred
         
         @param uModel1 3D model entity
         @param uModel2 3D model entity
         @param dt      Time-step value
         
         @return Returns true if collision occurred
         */
        virtual bool collision(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,float dt){};
        
        /**
         @brief Method which returns the currect SIMPLEXDATA structure
         
         @return Returns the current SIMPLEXDATA structure
         */
        virtual std::vector<SIMPLEXDATA> getCurrentSimpleStruct(){};
        
        /**
         @brief Method which returns the closest 3D point to the origin
         
         @return Returns closest 3D point to origin
         */
        virtual U4DPoint3n getClosestPointToOrigin(){};
        
        /**
         @brief Method which returns the closest collision point
         
         @return Returns the closest collision point
         */
        virtual U4DPoint3n getClosestCollisionPoint(){};

        /**
         @brief Method which returns the contact collision normal vector
         
         @return Returns the contact collision normal vector
         */
        virtual U4DVector3n getContactCollisionNormal(){};
        
    };

}

#endif /* defined(__UntoldEngine__U4DCollisionAlgorithm__) */
