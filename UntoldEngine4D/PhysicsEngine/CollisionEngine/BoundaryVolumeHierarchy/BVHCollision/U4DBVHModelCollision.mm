//
//  U4DBVHModelCollision.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/9/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "U4DBVHModelCollision.h"
#include "U4DBVHTree.h"
#include "U4DDynamicModel.h"
#include "U4DBoundingVolume.h"
#include "U4DBoundingSphere.h"
#include "U4DBroadPhaseCollisionModelPair.h"

namespace U4DEngine {
    
    U4DBVHModelCollision::U4DBVHModelCollision(){
        
    }
    
    U4DBVHModelCollision::~U4DBVHModelCollision(){
        
    }
    
    void U4DBVHModelCollision::startCollision(std::vector<std::shared_ptr<U4DBVHTree>>& uTreeContainer, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs){
       
        //get root tree
        U4DBVHTree *child=uTreeContainer.at(0).get()->next;
        
        while (child!=NULL) {
            
            if(child->isRoot()){
                
                
            }else{
                
                if (child->getFirstChild()!=NULL) {

                    collision(child->getFirstChild(), child->getLastChild(), uBroadPhaseCollisionPairs);
                    
                }
                
            }
            
            child=child->next;
        }
        
    }
    
    void U4DBVHModelCollision::collision(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs){
        
        //No collision between tree volumes, then exit
        if (!collisionBetweenTreeVolume(uTreeLeftNode,uTreeRightNode)) return;
        
        if (uTreeLeftNode->getFirstChild()==NULL && uTreeRightNode->getFirstChild()==NULL) {
            
            //At leaf nodes, perform collision tests on leaf node contents
            collisionBetweenTreeLeafNodes(uTreeLeftNode,uTreeRightNode, uBroadPhaseCollisionPairs);
            
        }else{
            
            if (descendTreeRule(uTreeLeftNode,uTreeRightNode)) {
                
                collision(uTreeLeftNode->getFirstChild(), uTreeRightNode, uBroadPhaseCollisionPairs);
                
                collision(uTreeLeftNode->getLastChild(), uTreeRightNode, uBroadPhaseCollisionPairs);
                
            }else{
                
                collision(uTreeLeftNode, uTreeRightNode->getFirstChild(), uBroadPhaseCollisionPairs);
                
                collision(uTreeLeftNode, uTreeRightNode->getLastChild(), uBroadPhaseCollisionPairs);
                
            }
        }
        
    }
    
    void U4DBVHModelCollision::collisionBetweenTreeLeafNodes(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs){
        
        //Test collision between leaf nodes
        U4DBoundingVolume *broadPhaseVolume1=uTreeLeftNode->getModelsContainer().at(0)->getBroadPhaseBoundingVolume();
        U4DBoundingVolume *broadPhaseVolume2=uTreeRightNode->getModelsContainer().at(0)->getBroadPhaseBoundingVolume();
        
        //Get the spheres from each bounding volume
        U4DSphere sphereVolume1=broadPhaseVolume1->getSphere();
        U4DSphere sphereVolume2=broadPhaseVolume2->getSphere();
        
        bool collisionOccurred=sphereVolume1.intersectionWithVolume(sphereVolume2);
        
        
        if (collisionOccurred) {
            
            U4DBroadPhaseCollisionModelPair pairs;
            pairs.model1=uTreeLeftNode->getModelsContainer().at(0);
            pairs.model2=uTreeRightNode->getModelsContainer().at(0);
            
            uBroadPhaseCollisionPairs.push_back(pairs);
            
        }
        
    }
    
}