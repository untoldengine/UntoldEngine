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
                
                //if (child->getFirstChild()!=NULL) {

                    collision(child->getFirstChild(), child->getLastChild(), uBroadPhaseCollisionPairs);
                    
                //}
                
            }
            
            child=child->next;
        }
        
    }
    
    void U4DBVHModelCollision::collision(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs){
        
        if(uTreeLeftNode==NULL && uTreeRightNode==NULL) return;
        
        //No collision between tree volumes, then exit
        if (!collisionBetweenTreeVolume(uTreeLeftNode,uTreeRightNode)) return;
        
        if (uTreeLeftNode->isLeaf() && uTreeRightNode->isLeaf()) {
            
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
        
        
        std::vector<ModelBoundingVolumePair> modelBoundingVolumePair;
        
        //get all the models from the left tree and add to modelbounding container
        for(auto n:uTreeLeftNode->getModelsContainer()){
            
            ModelBoundingVolumePair modelVolume;
            
            modelVolume.model=n;
            
            modelVolume.boundingVolume=n->getBroadPhaseBoundingVolume();
            
            modelBoundingVolumePair.push_back(modelVolume);
        }

        //get all the models from the right tree and add to modelbounding container
        for(auto n:uTreeRightNode->getModelsContainer()){
            
            ModelBoundingVolumePair modelVolume;
            
            modelVolume.model=n;
            
            modelVolume.boundingVolume=n->getBroadPhaseBoundingVolume();

            modelBoundingVolumePair.push_back(modelVolume);
        }

        //test for all leaf collisions
        for (int i=0; i<modelBoundingVolumePair.size()-1; i++) {
            
            
            
            for (int j=i+1; j<modelBoundingVolumePair.size(); j++) {
                
                bool collisionOccurred=false;
                
                
                //check if both models are not platforms
                if (!modelBoundingVolumePair.at(i).model->getIsPlatform() && !modelBoundingVolumePair.at(j).model->getIsPlatform()) {
                    
                    U4DSphere sphereVolume1=modelBoundingVolumePair.at(i).boundingVolume->getSphere();
                    
                    U4DSphere sphereVolume2=modelBoundingVolumePair.at(j).boundingVolume->getSphere();
                    
                    collisionOccurred=sphereVolume1.intersectionWithVolume(sphereVolume2);
                    
                    //check if model 1 is platform and model 2 is not platform
                }else if(modelBoundingVolumePair.at(i).model->getIsPlatform() && !modelBoundingVolumePair.at(j).model->getIsPlatform()){
                    
                    //get AABB for model 1
                    U4DAABB aabbVolume;
                    aabbVolume.maxPoint=modelBoundingVolumePair.at(i).boundingVolume->getMaxBoundaryPoint();
                    aabbVolume.minPoint=modelBoundingVolumePair.at(i).boundingVolume->getMinBoundaryPoint();
                    
                    U4DSphere sphereVolume=modelBoundingVolumePair.at(j).boundingVolume->getSphere();
                    
                    collisionOccurred=aabbVolume.intersectionWithVolume(sphereVolume);
                    
                    
                    
                    //check if model 1 is not platform and model 2 is a platform
                }else if(!modelBoundingVolumePair.at(i).model->getIsPlatform() && modelBoundingVolumePair.at(j).model->getIsPlatform()){
                    
                    //get AABB for model 2
                    U4DAABB aabbVolume;
                    aabbVolume.maxPoint=modelBoundingVolumePair.at(j).boundingVolume->getMaxBoundaryPoint();
                    aabbVolume.minPoint=modelBoundingVolumePair.at(j).boundingVolume->getMinBoundaryPoint();
                    
                    U4DSphere sphereVolume=modelBoundingVolumePair.at(i).boundingVolume->getSphere();
                    
                    collisionOccurred=aabbVolume.intersectionWithVolume(sphereVolume);
                    
                    
                    //both models are platforms
                }else{
                    
                    //get AABB for model 1
                    U4DAABB aabbVolume1;
                    aabbVolume1.maxPoint=modelBoundingVolumePair.at(i).boundingVolume->getMaxBoundaryPoint();
                    aabbVolume1.minPoint=modelBoundingVolumePair.at(i).boundingVolume->getMinBoundaryPoint();
                    
                    //get AABB for model 2
                    U4DAABB aabbVolume2;
                    aabbVolume2.maxPoint=modelBoundingVolumePair.at(j).boundingVolume->getMaxBoundaryPoint();
                    aabbVolume2.minPoint=modelBoundingVolumePair.at(j).boundingVolume->getMinBoundaryPoint();
                    
                    collisionOccurred=aabbVolume1.intersectionWithVolume(&aabbVolume2);
                    
                }
                
                if (collisionOccurred) {
                    
                    U4DBroadPhaseCollisionModelPair pairs;
                    pairs.model1=modelBoundingVolumePair.at(i).model;
                    pairs.model2=modelBoundingVolumePair.at(j).model;
                    
                    uBroadPhaseCollisionPairs.push_back(pairs);
                    
                }
                
            }
            
        }
        
    }
    
}