//
//  U4DBVHManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/13/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
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
    
    class U4DBVHManager{
        
    private:
        
        std::vector<U4DDynamicModel *> modelsContainer;
        U4DBVHCollision *bvhModelCollision;
        
    public:
        
        std::vector<U4DBroadPhaseCollisionModelPair> broadPhaseCollisionPairs;
        
        std::vector<std::shared_ptr<U4DBVHTree>> treeContainer;
        
        U4DBVHManager();
        
        ~U4DBVHManager();
        
        void buildBVH();
        
        void buildBVHNode(U4DBVHTree *uNode, int uLeftIndex, int uSplitIndex);
        
        std::vector<U4DDynamicModel *> getModelsContainer();
        
        void calculateBVHVolume(U4DBVHTree *uNode);
        
        void getBVHLongestDimensionVector(U4DBVHTree *uNode);
        
        void getBVHSplitIndex(U4DBVHTree *uNode);
        
        void addModelToTreeContainer(U4DDynamicModel* uModel);
        
        void startCollision();
        
        void heapSorting(U4DBVHTree *uNode);
        
        void reHeapDown(U4DBVHTree *uNode,int root, int bottom);
        
        void swap(U4DBVHTree *uNode,int uindex1, int uindex2);
        
        std::vector<U4DBroadPhaseCollisionModelPair> getBroadPhaseCollisionPairs();
        
        void clearContainers();
        
    };
    
}

#endif /* U4DBVHManager_hpp */

