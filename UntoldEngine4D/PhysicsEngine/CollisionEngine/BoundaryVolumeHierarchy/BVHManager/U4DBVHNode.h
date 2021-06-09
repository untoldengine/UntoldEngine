//
//  U4DBVHNode.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/8/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DBVHNode_hpp
#define U4DBVHNode_hpp

#include <stdio.h>
#include <vector>
#include "U4DPoint3n.h"
#include "U4DVector3n.h"
#include "U4DAABB.h"
#include "U4DEntityNode.h"

namespace U4DEngine {

    /**
     @ingroup physicsengine
     @brief The U4DBVHNode class represents a node in a BVH tree and is used for Broad-Phase collision.
     */
    template <typename T>
    class U4DBVHNode:public U4DEntityNode<U4DBVHNode<T>>{
        
    private:
        
        /**
         @brief AABB object which holds volume information about the node
         */
        U4DAABB* aabbVolume;
        
        /**
         @brief Tree node split index
         */
        int splitIndex;
        
        /**
         @brief Container holding 3D model entities
         */
        std::vector<T *> modelsContainer;
        
    public:
        
        /**
         @brief Constructor for the class
         */
        U4DBVHNode();
        
        /**
         @brief Destructor for the class
         */
        ~U4DBVHNode();
        
        /**
         @brief Method which returns container with 3D model entities that are part of the tree node
         
         @return Returns container with 3D model entities that are part of the tree node
         */
        std::vector<T *> getModelsContainer();
        
        /**
         @brief Method which adds 3D models to the node container
         
         @param uModel 3D model entity
         */
        void addModelToContainer(T *uModel);
        
        /**
         @brief Method which add a 3D model at a particular index
         
         @param uIndex           index
         @param uModel 3D model entity
         */
        void addModelToContainerAtIndex(int uIndex, T *uModel);
        
        /**
         @brief Method which makes a copy of the model container
         
         @param uModelsContainer Model container
         */
        void copyModelsContainer(std::vector<T *> uModelsContainer);
        
        /**
         @brief Method which returns a pointer to the AABB holding volume information about the tree node
         
         @return Returns a pointer to the AABB holding volume information about the tree node
         */
        U4DAABB* getAABBVolume();
        
        /**
         @brief Method which sets a tree node split index
         
         @param uSplitIndex Split index
         */
        void setSplitIndex(int uSplitIndex);
        
        /**
         @brief Method which returns the tree node split index
         
         @return Returns the tree node split index
         */
        int getSplitIndex();
    
    };
    
}

#include "U4DBVHNode.mm"
#endif /* U4DBVHNode_hpp */
