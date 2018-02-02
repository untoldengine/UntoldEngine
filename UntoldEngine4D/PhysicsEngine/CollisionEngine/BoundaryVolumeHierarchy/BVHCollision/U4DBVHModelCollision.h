//
//  U4DBVHModelCollision.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/9/16.
//  Copyright © 2016 Untold Engine Studios. All rights reserved.
//

#ifndef U4DBVHModelCollision_hpp
#define U4DBVHModelCollision_hpp

#include <stdio.h>
#include "U4DBVHCollision.h"

namespace U4DEngine {
    class U4DBVHTree;
    class U4DDynamicModel;
    class U4DBoundingVolume;
}

namespace U4DEngine {
    
    typedef struct{
        
        U4DDynamicModel *model;
        U4DBoundingVolume *boundingVolume;
        
    }ModelBoundingVolumePair;
}

namespace U4DEngine {

    /**
     @brief The U4DBVHModelCollision class is in charge of testing 3D model collisions in the broad-phase stage
     */
    class U4DBVHModelCollision:public U4DBVHCollision{
        
    private:
        
    public:
       
        /**
         @brief Constructor for the class
         */
        U4DBVHModelCollision();
        
        /**
         @brief Destructor for the class
         */
        ~U4DBVHModelCollision();
        
        /**
         @brief Method which starts the broad-phase collision detection process
         
         @param uTreeContainer            Tree container
         @param uBroadPhaseCollisionPairs Container holding broad-phase collision pairs
         */
        void startCollision(std::vector<std::shared_ptr<U4DBVHTree>>& uTreeContainer, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs);
        
        /**
         @brief Method which detects collisions
         
         @param uTreeLeftNode  Left tree node
         @param uTreeRightNode Right tree node
         @param uBroadPhaseCollisionPairs Container holding broad-phase collision pairs
         */
        void collision(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs);
        
        /**
         @brief Method which detects broad-phase collision among tree nodes
         
         @param uTreeLeftNode  Left tree node
         @param uTreeRightNode Right tree node
         @param uBroadPhaseCollisionPairs Container holding broad-phase collision pairs
         */
        void collisionBetweenTreeLeafNodes(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs);
        
    };
    
}

#endif /* U4DBVHModelCollision_hpp */
