//
//  U4DNavMesh.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/15/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "U4DNavMesh.h"
#include <queue>

namespace U4DEngine {
    
    U4DNavMesh::U4DNavMesh(){
        
    }
    
    U4DNavMesh::~U4DNavMesh(){
        
    }
    
    std::vector<U4DNavMeshNode> U4DNavMesh::getNavMeshNodeContainer(){
        
        return navMeshNodeContainer;
        
    }
    
    U4DNavMeshNode &U4DNavMesh::getNodeAt(int uIndex){
        
        return navMeshNodeContainer.at(uIndex);
        
    }
    
    int U4DNavMesh::getNodeIndexClosestToPosition(U4DVector3n &uPosition){
        
        //set up priority queue
        std::priority_queue<U4DNavMeshNode,std::vector<U4DNavMeshNode>, compareDistanceToPosition> q;
        
        //compute distance between each node and entity and store this in a priority queue
        
        for(auto n:navMeshNodeContainer){
            
            float distance=(n.position-uPosition.toPoint()).magnitude();
            
            n.distanceToDefinedPosition=distance;
            
            q.push(n);
            
        }
        
        U4DNavMeshNode nodeMesh=q.top();
        
        return nodeMesh.index;
        
    }
    
    void U4DNavMesh::clearNavMeshNodeInfo(){
        
        //clear all the information in the nav mesh.
        
        for(auto &n:navMeshNodeContainer){
            
            n.fCost=0.0;
            n.hCost=0.0;
            n.gCost=0.0;
            n.distanceToDefinedPosition=0.0;
            n.category=nodeInUnvisited;
            n.traversable=true;
            n.connection=0;
            
        }
        
    }
    
}
