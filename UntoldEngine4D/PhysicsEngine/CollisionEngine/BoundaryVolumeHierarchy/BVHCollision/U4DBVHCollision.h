//
//  U4DBVHCollisionInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/9/16.
//  Copyright © 2016 Untold Engine Studios. All rights reserved.
//

#ifndef U4DBVHCollisionInterface_hpp
#define U4DBVHCollisionInterface_hpp

#include <stdio.h>
#include <vector>
#include "U4DBVHNode.h"
#include "U4DNode.h"

namespace U4DEngine {
    
    class U4DBroadPhaseCollisionModelPair;
    class U4DDynamicModel;
}


namespace U4DEngine {

    /**
     @ingroup physicsengine
     @brief The U4DBVHCollision virtual class is in charge of testing collisions in the Broad-Phase stage
     */
    class U4DBVHCollision{
        
    private:
        
    public:
       
        /**
         @brief Constructor for the class
         */
        U4DBVHCollision();
        
        /**
         @brief Destructor for the class
         */
        ~U4DBVHCollision();
        
        /**
         @brief Method which tests collision among trees
         
         @param uTreeLeftNode  Left tree node
         @param uTreeRightNode Right tree node
         
         @return Returns true if the trees are colliding
         */
        bool collisionBetweenTreeVolume(U4DNode<U4DBVHNode<U4DDynamicModel>> *uTreeLeftNode, U4DNode<U4DBVHNode<U4DDynamicModel>> *uTreeRightNode);
        
        /**
         @brief Method used for the Tree descend rule
         
         @param uTreeLeftNode  Left tree node
         @param uTreeRightNode Right tree node
         
         @return Returns true if the left node first child is not a null pointer
         */
        bool descendTreeRule(U4DNode<U4DBVHNode<U4DDynamicModel>> *uTreeLeftNode, U4DNode<U4DBVHNode<U4DDynamicModel>> *uTreeRightNode);
        
        /**
         @brief Method which starts the broad-phase collision detection process
         
         @param uTreeContainer            Tree container
         @param uBroadPhaseCollisionPairs Container holding broad-phase collision pairs
         */
        virtual void startCollision(std::vector<std::shared_ptr<U4DNode<U4DBVHNode<U4DDynamicModel>>>>& uTreeContainer, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs){};
        
        /**
         @brief Method which detects collisions
         
         @param uTreeLeftNode  Left tree node
         @param uTreeRightNode Right tree node
         @param uBroadPhaseCollisionPairs Container holding broad-phase collision pairs
         */
        virtual void collision(U4DNode<U4DBVHNode<U4DDynamicModel>> *uTreeLeftNode, U4DNode<U4DBVHNode<U4DDynamicModel>> *uTreeRightNode, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs){};
        
        /**
         @brief Method which detects broad-phase collision among tree nodes
         
         @param uTreeLeftNode  Left tree node
         @param uTreeRightNode Right tree node
         @param uBroadPhaseCollisionPairs Container holding broad-phase collision pairs
         */
        virtual void collisionBetweenTreeLeafNodes(U4DNode<U4DBVHNode<U4DDynamicModel>> *uTreeLeftNode, U4DNode<U4DBVHNode<U4DDynamicModel>> *uTreeRightNode, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs){};
        
        /**
         @brief Document this
         */
        bool shouldModelsCollide(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2);
        
    };
}

#endif /* U4DBVHCollisionInterface_hpp */
