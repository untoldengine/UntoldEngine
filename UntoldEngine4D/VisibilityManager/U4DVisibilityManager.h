//
//  U4DVisibilityManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/30/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DVisibilityManager_hpp
#define U4DVisibilityManager_hpp

#include <stdio.h>
#include <vector>
#include "U4DDynamicModel.h"
#include "U4DVisibilityCulling.h"
#include "U4DCallback.h"

namespace U4DEngine {
    
    class U4DAABB;
    class U4DBVHTree;
    class U4DTimer;
}

namespace U4DEngine {
    
    /**
     @ingroup camera
     @brief The U4DVisibilityManager class tests whether a model is within the camera frustum
     */
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
        
        /**
         @brief pointer to class responsible for testing frustum culling
         */
        U4DVisibilityCulling visibilityCulling;
        
        /**
         @brief variable that tells the manager that it should pause the bvh build
         */
        bool isBVHBuildPaused;
        
        /**
         @brief time interval to build the bvh
         */
        int timeIntervalToBuildBVH;
        
        /**
         @brief scheduler for the bvh construction
         */
        
        U4DCallback<U4DVisibilityManager> *scheduler;
        
        /**
         @brief timer for the bvh construction
         */
        U4DTimer *timer;
        
    public:
        
        /**
         @brief class constructor
         */
        U4DVisibilityManager();
        
        /**
         @brief class destructor
         */
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
        
        /**
         @brief method to inform that the bvh should be built. This method sets a flag but does not initiate construction of the bvh

         @param uValue value to inform the manager to build the bvh
         */
        void setPauseBVHFBuild(bool uValue);
        
        /**
         @brief method that returns if the manager should build the BVH

         @return returns true if the manager should build the bvh. Note, it does not initiate initiate construcion of the bvh
         */
        bool getPauseBVHBuild();
        
        /**
         @brief This methods starts the timer for the next bvh build. Note, it simply starts a timer. Once the time has elapsed, it sets the computeBVHFlag. It does not initiate the construction of the bvh
         */
        void startTimerForNextBVHBuild();
        
        /**
         @brief Method that is called by the scheduler once the time interval has elapsed
         */
        void bvhTimerIntervalElapsed();
    
        /**
         @brief change the current visibility interval. The default is 0.5.
         @details This interval determines how fast the BVH is computed to determine which 3D models are within the camera frustum. The lower this interval, the faster the BVH is computed.
         @param uValue time interval.
         */
        void changeVisibilityInterval(float uValue);
        
    };
    
}

#endif /* U4DVisibilityManager_hpp */
