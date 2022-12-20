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
#include "U4DBVHNode.h"

namespace U4DEngine {
    
    class U4DDynamicAction;
    class U4DMesh;
}

namespace U4DEngine {
    
    typedef struct{
        
        U4DDynamicAction *model;
        U4DMesh *boundingVolume;
        
    }ModelBoundingVolumePair;
}

namespace U4DEngine {

    /**
     @ingroup physicsengine
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
        void startCollision(std::vector<std::shared_ptr<U4DBVHNode<U4DDynamicAction>>>& uTreeContainer, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs);
        
        /**
         @brief Method which detects collisions
         
         @param uTreeLeftNode  Left tree node
         @param uTreeRightNode Right tree node
         @param uBroadPhaseCollisionPairs Container holding broad-phase collision pairs
         */
        void collision(U4DBVHNode<U4DDynamicAction> *uTreeLeftNode, U4DBVHNode<U4DDynamicAction> *uTreeRightNode, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs);
        
        /**
         @brief Method which detects broad-phase collision among tree nodes
         
         @param uTreeLeftNode  Left tree node
         @param uTreeRightNode Right tree node
         @param uBroadPhaseCollisionPairs Container holding broad-phase collision pairs
         */
        void collisionBetweenTreeLeafNodes(U4DBVHNode<U4DDynamicAction> *uTreeLeftNode, U4DBVHNode<U4DDynamicAction> *uTreeRightNode, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs);
        
    };
    
}

#endif /* U4DBVHModelCollision_hpp */
