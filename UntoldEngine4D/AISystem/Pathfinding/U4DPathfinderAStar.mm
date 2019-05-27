//
//  U4DPathfinderAStar.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/15/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "U4DPathfinderAStar.h"
#include <algorithm>

namespace U4DEngine {
    
    U4DPathfinderAStar::U4DPathfinderAStar(){
        
       
        
    }
    
    U4DPathfinderAStar::~U4DPathfinderAStar(){
        
    }
    
    bool U4DPathfinderAStar::findPath(U4DNavMesh *uNavMesh, int uStartNodeIndex, int uEndNodeIndex, std::vector<U4DSegment> &uPath){
        
        if (uStartNodeIndex==uEndNodeIndex) {
            //the start and end node index can't be the same.
            return false;
            
        }
        
        U4DNavMeshNode &startNode=uNavMesh->getNodeAt(uStartNodeIndex);
        U4DNavMeshNode &endNode=uNavMesh->getNodeAt(uEndNodeIndex);
        
        std::vector<U4DNavMeshNode> pathNodes;
        
        //Initialize the Open List (heap data structure)
        //set cost to starting node
        setCost(startNode, startNode, endNode);
        startNode.category=nodeInOpen;
        
        openList.push_back(startNode);
        
        //Iterate processing each node
        
        while (openList.size()>0) {
            
            //Find the smallest node element in the open list with the lowest f_cost
            int minElementIndex=openList.at(0).index;
            U4DNavMeshNode &currentNode=uNavMesh->getNodeAt(minElementIndex);
            
            //if the node is the target node, then stop
            if (currentNode.index==endNode.index) {
                
                //path found
                
                //add ending node
                pathNodes.push_back(endNode);
                
                while (currentNode.index!=startNode.index) {
                    
                    int pathNodeIndex=currentNode.connection;
                    currentNode=uNavMesh->getNodeAt(pathNodeIndex);
                    
                    pathNodes.push_back(currentNode);
                    
                }
                
                break;
                
            }
            
            //otherwise get the node's neighbors
            std::vector<int> neighboursIndex=currentNode.getMeshNodeNeighborsIndex();
            
            //loop through each neighbor
            for (auto n:neighboursIndex) {
                
                U4DNavMeshNode &neighbourNode=uNavMesh->getNodeAt(n);
                
                //if the node is not traversable or neighbor is closed, then skip to the next neighbor
                if (neighbourNode.traversable==false || neighbourNode.category==nodeInClosed) {
                    //skip to the next neighbour
                    continue;
                }
                
                //compute cost for current neighbour
                setCost(neighbourNode, startNode, endNode);
                
                //if new path to neighbor is shorter or neighbor is not in the Open list
                if (neighbourNode.fCost<currentNode.fCost || neighbourNode.category!=nodeInOpen) {
                    
                    //set connection of neighbor to current node
                    neighbourNode.connection=currentNode.index;
                    
                    //if neighbour is not in the open list, add it to the Open list
                    if(neighbourNode.category!=nodeInOpen){
                        
                        neighbourNode.category=nodeInOpen;
                        openList.push_back(neighbourNode);
                        
                        
                    }
                    
                    
                }
                
                
            }
            
            //remove current node from open list and set it as closed
            
            int nodeToRemove=currentNode.index;
            
            openList.erase(std::remove_if(openList.begin(), openList.end(),[nodeToRemove](U4DNavMeshNode &e){ return (e.index==nodeToRemove);} ),openList.end());
            
            currentNode.category=nodeInClosed;
            
            //heapsort
            heapSort();
            
        }
       
        //setup path if it exists and return true
        if (pathNodes.size()>1) {
        
            uPath=assemblePath(pathNodes);
            
            return true;
            
        }
        
        //no path was found
        return false;
        
    }
    
    std::vector<U4DSegment> U4DPathfinderAStar::assemblePath(std::vector<U4DNavMeshNode> &uNavMeshNodes){
        
        //reverse the path
        std::reverse(uNavMeshNodes.begin(),uNavMeshNodes.end());
        
        std::vector<U4DSegment> path;
        
        //set up the path
        
        for(int i=0;i<uNavMeshNodes.size()-1;i++){
            
            U4DSegment segmentPath;
            segmentPath.pointA=uNavMeshNodes.at(i).position;
            segmentPath.pointB=uNavMeshNodes.at(i+1).position;
            
            path.push_back(segmentPath);
            
        }

        return path;
        
    }
    
    void U4DPathfinderAStar::setCost(U4DNavMeshNode &uCurrentNode, U4DNavMeshNode &uStartNode, U4DNavMeshNode &uEndNode){
        
        //distance from starting node
        uCurrentNode.gCost=(uCurrentNode.position-uStartNode.position).magnitude();
        
        //Heuristic value, distance from end node
        uCurrentNode.hCost=(uCurrentNode.position-uEndNode.position).magnitude();
        
        //set fCost=gCost+hCost
        uCurrentNode.fCost=uCurrentNode.gCost+uCurrentNode.hCost;
        
    }
    
    
    void U4DPathfinderAStar::reHeapDown(int root, int bottom){
        
        int maxChild;
        int rightChild;
        int leftChild;
        
        leftChild=root*2+1;
        rightChild=root*2+2;
        
        if (leftChild<=bottom) {
            
            if (leftChild==bottom) {
                
                maxChild=leftChild;
                
            }else{
                
                if (openList.at(leftChild).fCost<=openList.at(rightChild).fCost) {
                    
                    maxChild=rightChild;
                    
                }else{
                    maxChild=leftChild;
                }
            }
            
            if (openList.at(root).fCost<openList.at(maxChild).fCost) {
                
                swap(root,maxChild);
                reHeapDown(maxChild,bottom);
            }
        }
        
    }
    
    
    void U4DPathfinderAStar::heapSort(){
        
        int index; //index of node element
        
        int numValues=(int)openList.size();
        
        //convert the array of values into a heap
        
        for (index=numValues/2-1; index>=0; index--) {
            
            reHeapDown(index,numValues-1);
        }
        
        //sort the array
        for (index=numValues-1; index>=1; index--) {
            
            swap(0,index);
            reHeapDown(0,index-1);
        }
    }
    
    void U4DPathfinderAStar::swap(int uIndex1, int uIndex2){
        
        U4DNavMeshNode navMeshNode1=openList.at(uIndex1);
        U4DNavMeshNode navMeshNode2=openList.at(uIndex2);
        
        openList.at(uIndex1)=navMeshNode2;
        openList.at(uIndex2)=navMeshNode1;
        
    }
    
}
