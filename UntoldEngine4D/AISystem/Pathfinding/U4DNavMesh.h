//
//  U4DNavMesh.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/15/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DNavMesh_hpp
#define U4DNavMesh_hpp

#include <stdio.h>
#include <vector>
#include "U4DNavMeshNode.h"
#include "U4DVector3n.h"

namespace U4DEngine {
    
    //compare the distance between node to defined position
    struct compareDistanceToPosition{
        
        bool operator()(U4DNavMeshNode const &node1, U4DNavMeshNode const &node2){
            
            return node1.distanceToDefinedPosition>node2.distanceToDefinedPosition;
            
        }
        
    };
    
}
namespace U4DEngine {
 
    /**
     @ingroup artificialintelligence
     @brief The U4DNavMesh class represents the navigation mesh. It contains the navigatio mesh nodes extracted from the navigation mesh loader
     */
    class U4DNavMesh {
        
    private:
        
    public:
        
        /**
         @brief vector containing the navigation mesh nodes
         */
        std::vector<U4DNavMeshNode> navMeshNodeContainer;
        
        /**
         @brief class constructor
         */
        U4DNavMesh();
        
        /**
         @brief class destructor
         */
        ~U4DNavMesh();
        
        
        /**
         @brief gets the vector containing the navigation mesh nodes

         @return navigation mesh node vector
         */
        std::vector<U4DNavMeshNode> getNavMeshNodeContainer();
        
        
        /**
         @brief gets the node stored at the specified index in the container

         @param uIndex vector index
         @return node stored at specified index location
         */
        U4DNavMeshNode &getNodeAt(int uIndex);
        
        
        /**
         @brief gets the node index closest to the specified position. Used to determine the closest node to a location in the world

         @param uPosition position in world
         @return closest node index to the given position
         */
        int getNodeIndexClosestToPosition(U4DVector3n &uPosition);
        
    };
    
}

#endif /* U4DNavMesh_hpp */
