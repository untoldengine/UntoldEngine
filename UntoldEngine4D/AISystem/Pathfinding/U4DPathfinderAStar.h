//
//  U4DPathfinderAStar.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/15/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPathfinderAStar_hpp
#define U4DPathfinderAStar_hpp

#include <stdio.h>
#include "U4DSegment.h"
#include "U4DNavMesh.h"
#include "U4DNavMeshNode.h"

namespace U4DEngine {
 
    /**
     @ingroup artificialintelligence
     @brief The U4DPathfinderAStar class implements the Path Finding algorithm known as A Star algorithm
     */
    class U4DPathfinderAStar {
        
    private:
        
        /**
         @brief vector containing mesh nodes in the open list
         */
        std::vector<U4DNavMeshNode> openList;
        
    public:
        
        /**
         @brief class constructor
         */
        U4DPathfinderAStar();
        
        /**
         @brief class destructor
         */
        ~U4DPathfinderAStar();
        
        
        /**
         @brief computes the path using the A Star algorithm

         @param uNavMesh navigation mesh containing the nav mesh nodes
         @param uStartNodeIndex starting node to compute path
         @param uEndNodeIndex ending node to compute path
         @param uPath vector containing the computed path segments
         @return true if the path was able to be determined
         */
        bool findPath(U4DNavMesh *uNavMesh, int uStartNodeIndex, int uEndNodeIndex, std::vector<U4DSegment> &uPath);
        
        
        /**
         @brief assembles the path computed using the A Star algorithm

         @param uNavMeshNodes nav mesh nodes creating the path
         @return container with segments representing the computed path
         */
        std::vector<U4DSegment> assemblePath(std::vector<U4DNavMeshNode> &uNavMeshNodes);
        
        
        /**
         @brief sorts the heap data structure using a heap-down implementation

         @param root root node in the data structure
         @param bottom bottom node in the data structure
         */
        void reHeapDown(int root, int bottom);
        
        
        /**
         @brief sorts the Head data structure. The lowest value is at the root
         */
        void heapSort();
        
        
        /**
         @brief swaps the nodes indices. This is used to sort the Head data structure

         @param uIndex1 node1 index
         @param uIndex2 node2 index
         */
        void swap(int uIndex1, int uIndex2);
        
        
        /**
         @brief sets the gCost, hCost and total cost of the current nav mesh node

         @param uCurrentNode current mesh node
         @param uStartNode start mesh node
         @param uEndNode end mesh node
         */
        void setCost(U4DNavMeshNode &uCurrentNode, U4DNavMeshNode &uStartNode, U4DNavMeshNode &uEndNode);
        
        
    };
    
}

#endif /* U4DPathfinderAStar_hpp */
