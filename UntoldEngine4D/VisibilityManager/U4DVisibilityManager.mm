//
//  U4DVisibilityManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/30/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DVisibilityManager.h"
#include "U4DPlane.h"
#include "U4DBoundingAABB.h"
#include "U4DBoundingVolume.h"
#include "U4DPoint3n.h"
#include "U4DNumerical.h"
#include "U4DTimer.h"

namespace U4DEngine {
    
    U4DVisibilityManager::U4DVisibilityManager():isBVHBuildPaused(true),timeIntervalToBuildBVH(0.5){
        
        scheduler=new U4DCallback<U4DVisibilityManager>;
        
        timer=new U4DTimer(scheduler);
        
        scheduler->scheduleClassWithMethodAndDelay(this, &U4DVisibilityManager::bvhTimerIntervalElapsed, timer,timeIntervalToBuildBVH, true);
        
    }
    
    U4DVisibilityManager::~U4DVisibilityManager(){
        
        delete scheduler;
        delete timer;
    }
    
    void U4DVisibilityManager::addModelToTreeContainer(U4DModel* uModel){
        
        modelsContainer.push_back(uModel);
        
    }
    
    std::vector<U4DModel *> U4DVisibilityManager::getModelsContainer(){
        
        return modelsContainer;
    }
    
    void U4DVisibilityManager::setPauseBVHFBuild(bool uValue){
        
        isBVHBuildPaused=uValue;
    }
    
    bool U4DVisibilityManager::getPauseBVHBuild(){
        
        return isBVHBuildPaused;
    }
    
    void U4DVisibilityManager::bvhTimerIntervalElapsed(){
     
        isBVHBuildPaused=true;
        
        timer->setPause(true);
        
    }
    
    void U4DVisibilityManager::startTimerForNextBVHBuild(){
        
        timer->setPause(false);
        
    }
    
    void U4DVisibilityManager::buildBVH(){
        
        //create parent node
        std::shared_ptr<U4DBVHNode<U4DModel>> root(new U4DBVHNode<U4DModel>());
        
        treeContainer.push_back(root);
        
        //copy all models into container
        root->copyModelsContainer(modelsContainer);
        
        //start building the nodes
        buildBVHNode(root.get(), 0, getModelsContainer().size());
        
    }
    
    void U4DVisibilityManager::buildBVHNode(U4DBVHNode<U4DModel> *uNode, int uLeftIndex, int uSplitIndex){
        
        //1. Create node with current objects
        std::shared_ptr<U4DBVHNode<U4DModel>> nodeLeaf(new U4DBVHNode<U4DModel>());
        
        treeContainer.push_back(nodeLeaf);
        
        //add it as child
        uNode->addChild(nodeLeaf.get());
        
        //load models in to container
        for (int i=uLeftIndex; i<uSplitIndex; i++) {
            
            U4DModel *model=uNode->getModelsContainer().at(i);
            
            nodeLeaf->addModelToContainer(model);
            
        }
        
        //2. Calculate volume
        calculateBVHVolume(nodeLeaf.get());
        
        //3. get longest dimension
        getBVHLongestDimensionVector(nodeLeaf.get());
        
        //check if the node leaf has more than 1 models, if it does then split it recursively, else stop
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
    
    
    void U4DVisibilityManager::calculateBVHVolume(U4DBVHNode<U4DModel> *uNode){
        
        float xMin=FLT_MAX;
        float xMax=FLT_MIN;
        float yMin=FLT_MAX;
        float yMax=FLT_MIN;
        float zMin=FLT_MAX;
        float zMax=FLT_MIN;
        
        //get the min and max points for the volume
        
        for (const auto& n:uNode->getModelsContainer()) {
            
            U4DBoundingVolume *aabb=n->getCullingPhaseBoundingVolume();
            
            U4DPoint3n minPoints=aabb->getMinBoundaryPoint();
            U4DPoint3n maxPoints=aabb->getMaxBoundaryPoint();
            
            xMin=std::min(minPoints.x, xMin);
            yMin=std::min(minPoints.y, yMin);
            zMin=std::min(minPoints.z, zMin);
            
            xMax=std::max(maxPoints.x, xMax);
            yMax=std::max(maxPoints.y, yMax);
            zMax=std::max(maxPoints.z, zMax);
            
        }
        
        //assign volume min and max values to node
        U4DPoint3n maxPoint(xMax,yMax,zMax);
        uNode->getAABBVolume()->setMaxPoint(maxPoint);
        
        U4DPoint3n minPoint(xMin,yMin,zMin);
        uNode->getAABBVolume()->setMinPoint(minPoint);
        
    }
    
    void U4DVisibilityManager::getBVHLongestDimensionVector(U4DBVHNode<U4DModel> *uNode){
        
        //get the longest dimension of the volume
        float xDimension=std::abs(uNode->getAABBVolume()->getMinPoint().x-uNode->getAABBVolume()->getMaxPoint().x);
        float yDimension=std::abs(uNode->getAABBVolume()->getMinPoint().y-uNode->getAABBVolume()->getMaxPoint().y);
        float zDimension=std::abs(uNode->getAABBVolume()->getMinPoint().z-uNode->getAABBVolume()->getMaxPoint().z);
        
        float longestDimension=0.0;
        U4DVector3n longestDimensionVector(0,0,0);
        
        longestDimension=std::max(xDimension, yDimension);
        longestDimension=std::max(zDimension, longestDimension);
        
        U4DNumerical comparison;
        
        if (comparison.areEqual(longestDimension, xDimension, U4DEngine::zeroEpsilon)) {
            
            longestDimensionVector=U4DVector3n(1,0,0);
            
        }else if(comparison.areEqual(longestDimension, yDimension, U4DEngine::zeroEpsilon)){
            
            longestDimensionVector=U4DVector3n(0,1,0);
            
        }else{
            
            longestDimensionVector=U4DVector3n(0,0,1);
            
        }
        
        uNode->getAABBVolume()->setLongestAABBDimensionVector(longestDimensionVector);
    }
    
    void U4DVisibilityManager::getBVHSplitIndex(U4DBVHNode<U4DModel> *uNode){
        
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
        
        for (const auto& n:uNode->getModelsContainer()) {
            
            float broadPhaseBoundingVolumePositionAlongVector=n->getCullingPhaseBoundingVolume()->getLocalPosition().dot(uNode->getAABBVolume()->getLongestAABBDimensionVector());
            
            float distance=std::fabs(broadPhaseBoundingVolumePositionAlongVector-halfDistance);
            
            tempVectorOfModelPosition.push_back(distance);
            
        }
        
        
        //Get the minimum element in the vector with the lowest distance to the half distance of the volue
        auto closestModelToHalfDistance=std::min_element(tempVectorOfModelPosition.cbegin(), tempVectorOfModelPosition.cend());
        
        //Get the actual index in the vector which corresponds to the minimum element
        int splitIndex=std::distance(tempVectorOfModelPosition.cbegin(), closestModelToHalfDistance);
        
        //make sure that the node doesn't end up with empty nodes.
        float positionOfModelAlongLongestVector=uNode->getModelsContainer().at(splitIndex)->getCullingPhaseBoundingVolume()->getLocalPosition().dot(uNode->getAABBVolume()->getLongestAABBDimensionVector());
        
        if ((positionOfModelAlongLongestVector<=halfDistance) && (splitIndex<uNode->getModelsContainer().size()-1)) {
            
            splitIndex++;
            
        }
        
        //the split index can't be zero. If it is, then the bvh tree will go into an infinitite recursion loop.
        if (splitIndex==0) {
            splitIndex++;
        }
        
        uNode->setSplitIndex(splitIndex);
        
    }
    
    
    void U4DVisibilityManager::heapSorting(U4DBVHNode<U4DModel> *uNode){
        
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
    
    void U4DVisibilityManager::reHeapDown(U4DBVHNode<U4DModel> *uNode,int root, int bottom){
        
        int maxChild;
        int rightChild;
        int leftChild;
        
        leftChild=root*2+1;
        rightChild=root*2+2;
        
        if (leftChild<=bottom) {
            
            if (leftChild==bottom) {
                
                maxChild=leftChild;
                
            }else{
                
                if (uNode->getModelsContainer().at(leftChild)->getCullingPhaseBoundingVolume()->getLocalPosition().dot(uNode->getAABBVolume()->getLongestAABBDimensionVector())<=uNode->getModelsContainer().at(rightChild)->getCullingPhaseBoundingVolume()->getLocalPosition().dot(uNode->getAABBVolume()->getLongestAABBDimensionVector())) {
                    
                    maxChild=rightChild;
                    
                }else{
                    maxChild=leftChild;
                }
            }
            
            if (uNode->getModelsContainer().at(root)->getCullingPhaseBoundingVolume()->getLocalPosition().dot(uNode->getAABBVolume()->getLongestAABBDimensionVector())<uNode->getModelsContainer().at(maxChild)->getCullingPhaseBoundingVolume()->getLocalPosition().dot(uNode->getAABBVolume()->getLongestAABBDimensionVector())) {
                
                swap(uNode,root,maxChild);
                reHeapDown(uNode,maxChild,bottom);
            }
        }
        
    }
    
    
    
    void U4DVisibilityManager::swap(U4DBVHNode<U4DModel> *uNode,int uIndex1, int uIndex2){
        
        U4DModel* model1=uNode->getModelsContainer().at(uIndex1);
        U4DModel* model2=uNode->getModelsContainer().at(uIndex2);
        
        uNode->addModelToContainerAtIndex(uIndex1, model2);
        uNode->addModelToContainerAtIndex(uIndex2, model1);
        
    }
    
    void U4DVisibilityManager::startFrustumIntersection(std::vector<U4DPlane> &uPlanes){
        
        visibilityCulling.startFrustumIntersection(treeContainer, uPlanes);
    }
    
    void U4DVisibilityManager::clearContainers(){
        
        modelsContainer.clear();
        treeContainer.clear();
        
    }
    
    void U4DVisibilityManager::changeVisibilityInterval(float uValue){
        
        timer->setPause(true);
        
        scheduler->unScheduleTimer(timer);
        
        timeIntervalToBuildBVH=uValue;
        
        scheduler->scheduleClassWithMethodAndDelay(this, &U4DVisibilityManager::bvhTimerIntervalElapsed, timer,timeIntervalToBuildBVH, true);
        
    }
    
}
