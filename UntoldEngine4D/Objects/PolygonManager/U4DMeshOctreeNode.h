//
//  U4DMeshOctreeNode.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/28/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DMeshOctreeNode_hpp
#define U4DMeshOctreeNode_hpp

#include <stdio.h>
#include <vector>
#include "U4DAABB.h"

namespace U4DEngine {
    
    /**
     @brief The U4DMeshOctreeNode class represents a node of the octree bounding a 3d model
     */
    class U4DMeshOctreeNode {
        
    private:
        
    public:
        
        /**
         @brief Vector container storing all the triangles(faces) intersecting the AABB node
         */
        std::vector<int> triangleIndexContainer;
        
        /**
         @brief AABB object which holds volume information about the node
         */
        U4DAABB aabbVolume;
        
        /**
         @brief Octree Node constructor
         */
        U4DMeshOctreeNode();
        
        /**
         @brief Octree Node destructor
         */
        ~U4DMeshOctreeNode();
        
        
        
        
    };
    
}


#endif /* U4DPolygonTree_hpp */
