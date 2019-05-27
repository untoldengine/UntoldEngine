//
//  U4DNavMeshNode.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/16/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "U4DNavMeshNode.h"

namespace U4DEngine {
    
    U4DNavMeshNode::U4DNavMeshNode():index(0),gCost(0.0),hCost(0.0),fCost(0.0),connection(0),category(nodeInUnvisited),traversable(true),distanceToDefinedPosition(0.0){
        
    }
    
    U4DNavMeshNode::~U4DNavMeshNode(){
        
    }
    
    std::vector<int> U4DNavMeshNode::getMeshNodeNeighborsIndex(){
        
        return neighborsIndex;
        
    }
    
}
