//
//  U4DCollisionResponse.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/28/16.
//  Copyright © 2016 Untold Engine Studios. All rights reserved.
//

#ifndef U4DCollisionResponse_hpp
#define U4DCollisionResponse_hpp

#include <stdio.h>
#include <vector>
#include "CommonProtocols.h"

namespace U4DEngine {
    
    class U4DDynamicAction;
    class U4DVector3n;
    
}

namespace U4DEngine {

    /**
     @ingroup physicsengine
     @brief The U4DCollisionResponse class is in charge of implementing the collision response in the engine
     */
    class U4DCollisionResponse{
        
    private:
        
    public:
       
        /**
         @brief Constructor for the class
         */
        U4DCollisionResponse();
        
        /**
         @brief Destructor for the class
         */
        ~U4DCollisionResponse();
        
        /**
         @brief Method which computes the collision resolution for each 3D entity
         
         @param uAction1                3D model entity
         @param uAction2                3D model entity
         @param uCollisionManifoldNode Collision manifold node
         */
        void collisionResolution(U4DDynamicAction* uAction1, U4DDynamicAction* uAction2,COLLISIONMANIFOLDONODE &uCollisionManifoldNode);
        
    };
}

#endif /* U4DCollisionResponse_hpp */
