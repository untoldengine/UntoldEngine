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
#include "U4DVector3n.h"

namespace U4DEngine {
    
    class U4DBVHTree;
    class U4DDynamicModel;
    
    class U4DBVHManager{
        
    private:
        
        U4DBVHTree *rootNode;
        
        U4DBVHTree *leftNode;
        
        U4DBVHTree *rightNode;
        
        std::vector<U4DDynamicModel *> models;
        
    public:
        
        U4DBVHManager();
        
        ~U4DBVHManager();
        
        void buildBVH();
        
        void buildBVHNode();
        
        void sortModels(U4DBVHTree *uNode);
        
        void calculateBVHVolume(U4DBVHTree *uNode);
        
        void getBVHLongestDimensionVector(U4DBVHTree *uNode);
        
        void getBVHSplitIndex(U4DBVHTree *uNode);
        
        void addModel(U4DDynamicModel* uModel);
        
        void clearModels();
        
        bool intersection();
        
        void heapSorting(U4DBVHTree *uNode);
        
        void reHeapDown(U4DBVHTree *uNode,int root, int bottom);
        
        void swap(U4DBVHTree *uNode,int uindex1, int uindex2);
        
        void binarySearchForSplitIndex(U4DBVHTree *uNode, float uHalfDistanceOfLongestDimenstion, int uFromLocation, int uToLocation);
        
    };
    
}

#endif /* U4DBVHManager_hpp */

