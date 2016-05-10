//
//  U4DBVHGroundCollision.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/9/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "U4DBVHGroundCollision.h"
#include "U4DBVHTree.h"
#include "U4DDynamicModel.h"
#include "U4DBoundingVolume.h"
#include "U4DBoundingSphere.h"
#include "U4DBroadPhaseCollisionModelPair.h"

namespace U4DEngine {
    
    U4DBVHGroundCollision::U4DBVHGroundCollision(){
        
    }
    
    U4DBVHGroundCollision::~U4DBVHGroundCollision(){
        
    }
    
    void U4DBVHGroundCollision::setGroundNode(std::shared_ptr<U4DBVHTree> uGroundNode){
        groundNode=uGroundNode;
        
    }
    
    void U4DBVHGroundCollision::startCollision(std::vector<std::shared_ptr<U4DBVHTree>>& uTreeContainer, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs){
        
        //get root tree
        U4DBVHTree *child=uTreeContainer.at(0)->getFirstChild();
        
        while (child!=NULL) {
            
            if(child->isRoot()){
                
                
            }else{
                
                collision(groundNode.get(), child, uBroadPhaseCollisionPairs);
                
            }
            
            child=child->next;
        }
        
    }
    
    void U4DBVHGroundCollision::collision(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs){
        
        //No collision between tree volumes, then exit
        if (!collisionBetweenTreeVolume(uTreeLeftNode,uTreeRightNode)) return;
        
        if (uTreeRightNode->getFirstChild()==NULL) {
            
            //At leaf nodes, perform collision tests on leaf node contents
            collisionBetweenTreeLeafNodes(uTreeLeftNode,uTreeRightNode,uBroadPhaseCollisionPairs);
            
        }else{
            
            collision(uTreeLeftNode, uTreeRightNode->getFirstChild(),uBroadPhaseCollisionPairs);
            
            collision(uTreeLeftNode, uTreeRightNode->getLastChild(),uBroadPhaseCollisionPairs);
            
        }
        
    }
    
    void U4DBVHGroundCollision::collisionBetweenTreeLeafNodes(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs){
        
        //Test collision between leaf nodes
        U4DBoundingVolume *broadPhaseVolume1=uTreeLeftNode->getModelsContainer().at(0)->getBroadPhaseBoundingVolume();
        U4DBoundingVolume *broadPhaseVolume2=uTreeRightNode->getModelsContainer().at(0)->getBroadPhaseBoundingVolume();
        
        //Get the spheres from each bounding volume
        U4DAABB aabbVolume=broadPhaseVolume1->getAABB();
        U4DSphere sphereVolume=broadPhaseVolume2->getSphere();
        
        bool collisionOccurred=aabbVolume.intersectionWithVolume(sphereVolume);
        
        
        if (collisionOccurred) {
            
            U4DBroadPhaseCollisionModelPair pairs;
            pairs.model1=uTreeLeftNode->getModelsContainer().at(0);
            pairs.model2=uTreeRightNode->getModelsContainer().at(0);
            
            uBroadPhaseCollisionPairs.push_back(pairs);
            
        }
    }
    
}