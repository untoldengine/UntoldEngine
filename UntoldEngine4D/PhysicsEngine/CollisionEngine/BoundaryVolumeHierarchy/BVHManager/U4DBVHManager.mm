//
//  U4DBVHManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/13/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "U4DBVHManager.h"
#include "U4DBVHTree.h"
#include "U4DVector3n.h"
#include "U4DDynamicModel.h"
#include "U4DBoundingVolume.h"
#include "U4DBoundingSphere.h"
#include <cmath>
#include <cstdlib>
#include <stack>


namespace U4DEngine{
    
    U4DBVHManager::U4DBVHManager(){
        
    }
    
    U4DBVHManager::~U4DBVHManager(){
        
    }
    
    std::vector<U4DDynamicModel *> U4DBVHManager::getModelsContainer(){
        
        return modelsContainer;
    }
    
    void U4DBVHManager::addModelToTreeContainer(U4DDynamicModel* uModel){
        
        modelsContainer.push_back(uModel);
        
    }
    
    void U4DBVHManager::buildBVH(){
        
        //create parent node
        
        std::shared_ptr<U4DBVHTree> root(new U4DBVHTree());
        
        treeContainer.push_back(root);
        
        //copy all models into container
        root->copyModelsContainer(modelsContainer);
        
        //start building the nodes
        buildBVHNode(root.get(), 0, getModelsContainer().size());
        
    }
    
    void U4DBVHManager::buildBVHNode(U4DBVHTree *uNode, int uLeftIndex, int uSplitIndex){
        
        //1. Create node with current objects
        std::shared_ptr<U4DBVHTree> nodeLeaf(new U4DBVHTree());
        
        treeContainer.push_back(nodeLeaf);
        
        //add it as child
        uNode->addChild(nodeLeaf.get());
        
        //load models in to container
        for (int i=uLeftIndex; i<uSplitIndex; i++) {
            
            U4DDynamicModel *model=uNode->getModelsContainer().at(i);
            
            nodeLeaf->addModelToContainer(model);
            
        }
        
        //2. Calculate volume
        calculateBVHVolume(nodeLeaf.get());
        
        //3. get longest dimension
        getBVHLongestDimensionVector(nodeLeaf.get());
        
        //check if the node leaf has more than two models, if it does then split it recursively, else stop
        if (nodeLeaf->getModelsContainer().size()>1) {
            
            //4. sort objects along the longest dimension
            heapSorting(nodeLeaf.get());
                
            //5. get split index
            getBVHSplitIndex(nodeLeaf.get());
            
            //6. build left and right node
            buildBVHNode(nodeLeaf.get(), 0, nodeLeaf->getSplitIndex());
            buildBVHNode(nodeLeaf.get(), nodeLeaf->getSplitIndex(), nodeLeaf->getModelsContainer().size());
        
        
        }
        
    }
    
    void U4DBVHManager::startCollision(){
        
        //get root tree
        U4DBVHTree *child=treeContainer.at(0)->getFirstChild();
        
        while (child!=NULL) {
            
            if(child->isRoot()){
                
                
            }else{
                
                if (child->getFirstChild()!=NULL) {
                    
                    collision(child->getFirstChild(), child->getLastChild());
                    
                }
                
            }
            
            child=child->next;
        }
        
    }
    
    
    void U4DBVHManager::collision(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode){
        
        
        //No collision between tree volumes, then exit
        if (!collisionBetweenTreeVolume(uTreeLeftNode,uTreeRightNode)) return;
        
        if (uTreeLeftNode->getFirstChild()==NULL && uTreeRightNode->getFirstChild()==NULL) {
            
            //At leaf nodes, perform collision tests on leaf node contents
            collisionBetweenTreeLeafNodes(uTreeLeftNode,uTreeRightNode);
            
        }else{
            
            if (descendTreeRule(uTreeLeftNode,uTreeRightNode)) {
                
                collision(uTreeLeftNode->getFirstChild(), uTreeRightNode);
                
                collision(uTreeLeftNode->getLastChild(), uTreeRightNode);
                
            }else{
                
                collision(uTreeLeftNode, uTreeRightNode->getFirstChild());
                
                collision(uTreeLeftNode, uTreeRightNode->getLastChild());
                
            }
        }
        
    }
    
    bool U4DBVHManager::collisionBetweenTreeVolume(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode){
        
            return uTreeLeftNode->getAABBVolume()->intersectionWithVolume(uTreeRightNode->getAABBVolume());
        
    }
    
    void U4DBVHManager::collisionBetweenTreeLeafNodes(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode){
        
        //Test collision between leaf nodes
        U4DBoundingSphere *broadPhaseVolume1=(U4DBoundingSphere*)uTreeLeftNode->getModelsContainer().at(0)->getBroadPhaseBoundingVolume();
        U4DBoundingSphere *broadPhaseVolume2=(U4DBoundingSphere*)uTreeRightNode->getModelsContainer().at(0)->getBroadPhaseBoundingVolume();
    
        bool collisionOccurred=broadPhaseVolume1->intesectionWithBoundingVolume(broadPhaseVolume2);
        
    
        if (collisionOccurred) {
            std::cout<<"Broad Phase Collision Occurred"<<std::endl;
            
            U4DBroadPhaseCollisionModelPair pairs;
            pairs.model1=uTreeLeftNode->getModelsContainer().at(0);
            pairs.model2=uTreeRightNode->getModelsContainer().at(0);
            
            broadPhaseCollisionPairs.push_back(pairs);
            
        }
        
    }
    
    std::vector<U4DBroadPhaseCollisionModelPair> U4DBVHManager::getBroadPhaseCollisionPairs(){
        
        return broadPhaseCollisionPairs;
        
    }
    
    bool U4DBVHManager::descendTreeRule(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode){
        
        bool value=false;
        
        if (uTreeLeftNode->getFirstChild()!=NULL) {
            return value=true;
        }
        
        return value;
    }
    
    void U4DBVHManager::calculateBVHVolume(U4DBVHTree *uNode){
        
        float xMin=FLT_MAX;
        float xMax=FLT_MIN;
        float yMin=FLT_MAX;
        float yMax=FLT_MIN;
        float zMin=FLT_MAX;
        float zMax=FLT_MIN;
        
        //get the min and max points for the volume
        
        for (auto n:uNode->getModelsContainer()) {
        
            U4DBoundingVolume *sphere=n->getBroadPhaseBoundingVolume();
            
            U4DPoint3n minPoints=sphere->getMinBoundaryPoint();
            U4DPoint3n maxPoints=sphere->getMaxBoundaryPoint();
            
            xMin=MIN(minPoints.x, xMin);
            yMin=MIN(minPoints.y, yMin);
            zMin=MIN(minPoints.z, zMin);

            xMax=MAX(maxPoints.x, xMax);
            yMax=MAX(maxPoints.y, yMax);
            zMax=MAX(maxPoints.z, zMax);
            
        }
        
        //assign volume min and max values to node
        U4DPoint3n maxPoint(xMax,yMax,zMax);
        uNode->getAABBVolume()->setMaxPoint(maxPoint);
        
        U4DPoint3n minPoint(xMin,yMin,zMin);
        uNode->getAABBVolume()->setMinPoint(minPoint);
        
    }
    
    void U4DBVHManager::getBVHLongestDimensionVector(U4DBVHTree *uNode){
        
        //get the longest dimension of the volume
        float xDimension=std::abs(uNode->getAABBVolume()->getMinPoint().x-uNode->getAABBVolume()->getMaxPoint().x);
        float yDimension=std::abs(uNode->getAABBVolume()->getMinPoint().y-uNode->getAABBVolume()->getMaxPoint().y);
        float zDimension=std::abs(uNode->getAABBVolume()->getMinPoint().z-uNode->getAABBVolume()->getMaxPoint().z);
        
        float longestDimension=0.0;
        U4DVector3n longestDimensionVector(0,0,0);
        
        longestDimension=MAX(xDimension, yDimension);
        longestDimension=MAX(zDimension, longestDimension);
        
        if (longestDimension==xDimension) {
            
            longestDimensionVector=U4DVector3n(1,0,0);
            
        }else if(longestDimension==yDimension){
        
            longestDimensionVector=U4DVector3n(0,1,0);
        
        }else{
        
            longestDimensionVector=U4DVector3n(0,0,1);
        
        }
        
        uNode->getAABBVolume()->setLongestAABBDimensionVector(longestDimensionVector);
    }
    
    void U4DBVHManager::getBVHSplitIndex(U4DBVHTree *uNode){
        
        //split the longest dimension of the volume in half
        
        //get min point of volume
        U4DVector3n minBoundary=uNode->getAABBVolume()->getMinPoint().toVector();
        
        //get max point in volume
        U4DVector3n maxBoundary=uNode->getAABBVolume()->getMaxPoint().toVector();
        
        //half distance of longest dimension in volume
        float halfDistance=(maxBoundary.dot(uNode->getAABBVolume()->getLongestAABBDimensionVector())-minBoundary.dot(uNode->getAABBVolume()->getLongestAABBDimensionVector()))/2;
        
        halfDistance=maxBoundary.dot(uNode->getAABBVolume()->getLongestAABBDimensionVector())-halfDistance;
        
        //search for split index
        std::vector<float> tempVectorOfModelPosition;
        
        for (auto n:uNode->getModelsContainer()) {
            
            float broadPhaseBoundingVolumePositionAlongVector=n->getBroadPhaseBoundingVolume()->getLocalPosition().dot(uNode->getAABBVolume()->getLongestAABBDimensionVector());
            
            float distance=broadPhaseBoundingVolumePositionAlongVector-halfDistance;
            
            tempVectorOfModelPosition.push_back(distance);
        
        }
        
        
        //Get the minimum element in the vector with the lowest distance to the half distance of the volue
        auto closestModelToHalfDistance=std::min_element(tempVectorOfModelPosition.cbegin(), tempVectorOfModelPosition.cend());
        
        //Get the actual index in the vector which corresponds to the minimum element
        int splitIndex=std::distance(tempVectorOfModelPosition.cbegin(), closestModelToHalfDistance);
        
        //
        float positionOfModelAlongLongestVector=uNode->getModelsContainer().at(splitIndex)->getBroadPhaseBoundingVolume()->getLocalPosition().dot(uNode->getAABBVolume()->getLongestAABBDimensionVector());
        
        if (positionOfModelAlongLongestVector<halfDistance) {
            
            splitIndex++;
            
        }
        
        uNode->setSplitIndex(splitIndex);
        
    }
    
    
    void U4DBVHManager::heapSorting(U4DBVHTree *uNode){
        
        int index=0;
        
        int numValues=(int)uNode->getModelsContainer().size();
        
        //convert the array of values into a heap
        for (index=numValues/2-1; index>=0; index--) {
        
            reHeapDown(uNode,index,numValues-1);
        }
        
        //sort the array
        for (index=numValues-1; index>=1; index--) {
            
            swap(uNode,0,index);
            reHeapDown(uNode,0,index-1);
            
        }
        
    }
    
    void U4DBVHManager::reHeapDown(U4DBVHTree *uNode,int root, int bottom){
        
        int maxChild;
        int rightChild;
        int leftChild;
        
        leftChild=root*2+1;
        rightChild=root*2+2;
        
        if (leftChild<=bottom) {
            
            if (leftChild==bottom) {
                
                maxChild=leftChild;
                
            }else{
                
                if (uNode->getModelsContainer().at(leftChild)->getBroadPhaseBoundingVolume()->getLocalPosition().dot(uNode->getAABBVolume()->getLongestAABBDimensionVector())<=uNode->getModelsContainer().at(rightChild)->getBroadPhaseBoundingVolume()->getLocalPosition().dot(uNode->getAABBVolume()->getLongestAABBDimensionVector())) {
                    
                    maxChild=rightChild;
                    
                }else{
                    maxChild=leftChild;
                }
            }
            
            if (uNode->getModelsContainer().at(root)->getBroadPhaseBoundingVolume()->getLocalPosition().dot(uNode->getAABBVolume()->getLongestAABBDimensionVector())<uNode->getModelsContainer().at(maxChild)->getBroadPhaseBoundingVolume()->getLocalPosition().dot(uNode->getAABBVolume()->getLongestAABBDimensionVector())) {
                
                swap(uNode,root,maxChild);
                reHeapDown(uNode,maxChild,bottom);
            }
        }
        
    }
    
    
    
    void U4DBVHManager::swap(U4DBVHTree *uNode,int uIndex1, int uIndex2){
        
        U4DDynamicModel* model1=uNode->getModelsContainer().at(uIndex1);
        U4DDynamicModel* model2=uNode->getModelsContainer().at(uIndex2);
        
        uNode->addModelToContainerAtIndex(uIndex1, model2);
        uNode->addModelToContainerAtIndex(uIndex2, model1);
        
    }
    
    void U4DBVHManager::clearContainers(){
        
        modelsContainer.clear();
        treeContainer.clear();
        broadPhaseCollisionPairs.clear();
        
    }
    
}