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

        //test for all collisions
        for (int i=0; i<modelBoundingVolumePair.size()-1; i++) {
            
            U4DSphere sphereVolume1=modelBoundingVolumePair.at(i).boundingVolume->getSphere();
            
            for (int j=i+1; j<modelBoundingVolumePair.size(); j++) {
                
            U4DSphere sphereVolume2=modelBoundingVolumePair.at(j).boundingVolume->getSphere();
                
            bool collisionOccurred=sphereVolume1.intersectionWithVolume(sphereVolume2);
            
            std::cout<<"Collisions pair: "<<modelBoundingVolumePair.at(i).model->getName()<<" and " <<modelBoundingVolumePair.at(j).model->getName()<<std::endl;
                
                if (collisionOccurred) {
                    
                    U4DBroadPhaseCollisionModelPair pairs;
                    pairs.model1=modelBoundingVolumePair.at(i).model;
                    pairs.model2=modelBoundingVolumePair.at(j).model;
                    
                    uBroadPhaseCollisionPairs.push_back(pairs);
                    
                    std::cout<<"Collision occurred between: "<<pairs.model1->getName()<<" and "<<pairs.model2->getName()<<std::endl;
                }
                
            }
            
        }
        
        
//        //Test collision between leaf nodes
//        U4DBoundingVolume *broadPhaseVolume1=uTreeLeftNode->getModelsContainer().at(0)->getBroadPhaseBoundingVolume();
//        U4DBoundingVolume *broadPhaseVolume2=uTreeRightNode->getModelsContainer().at(0)->getBroadPhaseBoundingVolume();
//        
//        //Get the spheres from each bounding volume
//        U4DSphere sphereVolume1=broadPhaseVolume1->getSphere();
//        U4DSphere sphereVolume2=broadPhaseVolume2->getSphere();
//        
//        bool collisionOccurred=sphereVolume1.intersectionWithVolume(sphereVolume2);
//        
//        std::cout<<"Collisions pair: "<<uTreeLeftNode->getModelsContainer().at(0)->getName()<<" and " <<uTreeRightNode->getModelsContainer().at(0)->getName()<<std::endl;
//        
//        if (collisionOccurred) {
//            
//            U4DBroadPhaseCollisionModelPair pairs;
//            pairs.model1=uTreeLeftNode->getModelsContainer().at(0);
//            pairs.model2=uTreeRightNode->getModelsContainer().at(0);
//            
//            uBroadPhaseCollisionPairs.push_back(pairs);
//            
//        }
        
    }
    
}