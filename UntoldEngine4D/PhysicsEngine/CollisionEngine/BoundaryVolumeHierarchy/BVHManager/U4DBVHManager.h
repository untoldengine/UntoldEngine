//
//  U4DBVHManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/13/16.
//  Copyright © 2016 Untold Engine Studios. All rights reserved.
//

#ifndef U4DBVHManager_hpp
#define U4DBVHManager_hpp

#include <stdio.h>
#include <vector>
#include <memory>
#include "CommonProtocols.h"
#include "U4DVector3n.h"
#include "U4DBroadPhaseCollisionModelPair.h"
#include "U4DBVHCollision.h"


namespace U4DEngine {
    
    class U4DBVHTree;
    class U4DDynamicModel;
    class U4DBVHModelCollision;
    class U4DBVHGroundCollision;
    
}

namespace U4DEngine {

    /**
     @brief The U4DBVHManager class represents the Boundary Volume Hierarchy manager
     */
    class U4DBVHManager{
        
    private:
        
        /**
         @brief Container holding all 3D model entities
         */
        std::vector<U4DDynamicModel *> modelsContainer;
        
        /**
         @brief Pointer to the Boundary Volume Hierarchy algorithm
         */
        U4DBVHCollision *bvhModelCollision;
        
    public:
        
        /**
         @brief Container to the Broad-Phase collision pair
         */
        std::vector<U4DBroadPhaseCollisionModelPair> broadPhaseCollisionPairs;
        
        /**
         @brief Smart pointer to the root tree container
         */
        std::vector<std::shared_ptr<U4DBVHTree>> treeContainer;
        
        /**
         @brief Constructor of the class
         */
        U4DBVHManager();
        
        /**
         @brief Destructor of the class
         */
        ~U4DBVHManager();
        
        /**
         @brief Method which starts building the BVH algorithm
         */
        void buildBVH();
        
        /**
         @brief Method which builds a BVH tree node
         
         @param uNode       Tree node
         @param uLeftIndex  Left index
         @param uSplitIndex Split index
         */
        void buildBVHNode(U4DBVHTree *uNode, int uLeftIndex, int uSplitIndex);
        
        /**
         @brief Method which returns all 3D entities in the BVH tree
         
         @return Returns all 3D entities in the BVH tree
         */
        std::vector<U4DDynamicModel *> getModelsContainer();
        
        /**
         @brief Method which computes a BVH node volume
         
         @param uNode BVH tree node
         */
        void calculateBVHVolume(U4DBVHTree *uNode);
        
        /**
         @brief Method which computes the BVH node longest dimension vector
         
         @param uNode BVH tree node
         */
        void getBVHLongestDimensionVector(U4DBVHTree *uNode);
        
        /**
         @brief Method which computes a BVH node split index
         
         @param uNode BVH tree node
         */
        void getBVHSplitIndex(U4DBVHTree *uNode);
        
        /**
         @brief Method which adds a model to the model container
         
         @param uModel 3D model entity
         */
        void addModelToTreeContainer(U4DDynamicModel* uModel);
        
        /**
         @brief Method which starts testing Broad-Phase collisions
         */
        void startCollision();
        
        /**
         @brief Method to heap sort the BVH tree nodes
         
         @param uNode BVH tree node
         */
        void heapSorting(U4DBVHTree *uNode);
        
        /**
         @brief Method used to heap-down sort the BVH tree nodes
         
         @param uNode  BVH tree node
         @param root   Index of root node
         @param bottom bottom index
         */
        void reHeapDown(U4DBVHTree *uNode,int root, int bottom);
        
        /**
         @brief Method used to swap the BVH tree node's array index
         
         @param uNode   BVH tree node
         @param uindex1 Node array index
         @param uindex2 Node array index
         */
        void swap(U4DBVHTree *uNode,int uindex1, int uindex2);
        
        /**
         @brief Method which returns all broad-phase collision pairs
         
         @return Returns all broad-phase collision pairs
         */
        std::vector<U4DBroadPhaseCollisionModelPair> getBroadPhaseCollisionPairs();
        
        /**
         @brief Method which clears all broad-phase collision containers.
         */
        void clearContainers();
        
    };
    
}

#endif /* U4DBVHManager_hpp */

