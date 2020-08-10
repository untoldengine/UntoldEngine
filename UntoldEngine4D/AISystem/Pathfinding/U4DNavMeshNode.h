//
//  U4DNavMeshNode.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/16/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DNavMeshNode_hpp
#define U4DNavMeshNode_hpp

#include <stdio.h>
#include <vector>
#include "U4DPoint3n.h"

namespace U4DEngine {
    
    typedef enum{
        
        nodeInOpen,
        nodeInClosed,
        nodeInUnvisited
        
    }NavMeshNodeCategory;
    
}

namespace U4DEngine {
    
    /**
     @ingroup artificialintelligence
     @brief The U4DNavMeshNode class represents the navigation mesh node. The nav mesh node contains information required by the PathFinding algorithm.
     */
    class U4DNavMeshNode {
        
    public:
        
        /**
         @brief node index as retrieved from the mesh loader
         */
        int index;
        
        /**
         @brief node position
         */
        U4DPoint3n position;
        
        /**
         @brief node weights
         */
        float weight;
        
        /**
         @brief vector containing the neighbours of the node. The vector contains the indeces of the neighbours
         */
        std::vector<int> neighborsIndex;
        
        /**
         @brief distance from starting node
         */
        float gCost;
        
        /**
         @brief distance from end node
         */
        float hCost;
        
        /**
         @brief total cost of gCost and hCost
         */
        float fCost;
        
        /**
         @brief connection to parent node. This is used to trace the path after it has been computed
         */
        int connection;
        
        /**
         @brief is the node traversable
         */
        bool traversable;
        
        /**
         @brief used to determine if the node is in the open, closed or unvisited list
         */
        NavMeshNodeCategory category;
        
        /**
         @brief distance to specifed position
         */
        float distanceToDefinedPosition;
        
        /**
         @brief class constructor
         */
        U4DNavMeshNode();
        
        /**
         @brief class destructor
         */
        ~U4DNavMeshNode();
        
        
        /**
         @brief gets the node neighbours indices

         @return neighbours indices
         */
        std::vector<int> getMeshNodeNeighborsIndex();
        
    };
    
}


#endif /* U4DNavMeshNode_hpp */
