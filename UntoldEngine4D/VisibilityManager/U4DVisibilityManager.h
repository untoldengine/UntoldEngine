//
//  U4DVisibilityManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/30/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U4DVisibilityManager_hpp
#define U4DVisibilityManager_hpp

#include <stdio.h>
#include <vector>
#include "U4DDynamicModel.h"
#include "U4DVisibilityCulling.h"

namespace U4DEngine {
    
    class U4DAABB;
    class U4DBVHTree;
}

namespace U4DEngine {
    
    class U4DVisibilityManager {
        
    private:
        
        /**
         @brief Container holding all 3D model entities
         */
        std::vector<U4DDynamicModel *> modelsContainer;
        
        /**
         @brief Smart pointer to the root tree container
         */
        std::vector<std::shared_ptr<U4DBVHTree>> treeContainer;
        
        U4DVisibilityCulling visibilityCulling;
        
        
    public:
        
        U4DVisibilityManager();
        
        ~U4DVisibilityManager();
        
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
         @brief Starts the frustum vs model culling test

         @param uPlanes frustum planes
         */
        void startFrustumIntersection(std::vector<U4DPlane> &uPlanes);
        
        /**
         @brief Method which clears all broad-phase collision containers.
         */
        void clearContainers();
    };
    
}

#endif /* U4DVisibilityManager_hpp */
