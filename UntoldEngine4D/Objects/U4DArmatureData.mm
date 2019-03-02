//
//  U4DArmatureData.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/4/14.
//  Copyright (c) 2014 Untold Engine Studios. All rights reserved.
//

#include "U4DArmatureData.h"
#include "U4DBoneData.h"
#include "U4DModel.h"

namespace U4DEngine {
    
    U4DArmatureData::U4DArmatureData(U4DModel *uModel):rootBone(nullptr){

        u4dModel=uModel;
        
    }

    U4DArmatureData::~U4DArmatureData(){

        //Remove all bones
        std::vector<U4DBoneData*> removeBoneContainer;
        
        U4DBoneData *child=rootBone;
        
        while (child!=NULL) {
            
            removeBoneContainer.push_back(child);
            
            child=child->next;
        }
        
        
        for(auto n:removeBoneContainer){
            
            delete n;
            
        }
        
    }

    void U4DArmatureData::setRootBone(U4DBoneData* uBoneData){
        
        rootBone=uBoneData;
        
    }


    void U4DArmatureData::addBoneToTree(U4DBoneData *uParent, U4DBoneData *uChild){
        
        uParent->addBoneToTree(uChild);
        
        //update index count
        updateBoneIndexCount();
    }

    void U4DArmatureData::removeBoneFromTree(std::string uChildBoneName){
        
        U4DBoneData *uChild=rootBone->searchChildrenBone(uChildBoneName);
        
        if(rootBone!=NULL){
            
            rootBone->removeBoneFromTree(uChild);
        }
        
        //update index count
        updateBoneIndexCount();
    }

    void U4DArmatureData::updateBoneIndexCount(){
        
        //get parent bone
        U4DBoneData* boneChild = rootBone;
        
        int indexCount=0;
        
        //While there are still bones
        while (boneChild!=0) {
            
            //assign the index count
            boneChild->index=indexCount;
            
            //increment the index count
            indexCount++;
            
            //iterate to the next child
            boneChild=boneChild->next;
            
        }

    }

    void U4DArmatureData::setBoneDataContainer(){
        
        //get parent bone
        U4DBoneData* boneChild = rootBone;
        
        //add all bones into a vector
        
        //While there are still bones
        while (boneChild!=0) {
            
            //This vector will be copied to the boneDataContainer
            boneDataContainer.push_back(boneChild);
            
            //iterate to the next child
            boneChild=boneChild->next;
            
        }
        
    }

    void U4DArmatureData::setBoneAbsoluteSpace(){
        
        //get parent bone
        U4DBoneData* boneChild = rootBone;
        
        //While there are still bones
        while (boneChild!=0) {
            
            if (boneChild->isRoot()) {
                
                boneChild->absoluteSpace=boneChild->localSpace;
                
                
            }else{
                
                boneChild->absoluteSpace=boneChild->localSpace*boneChild->parent->absoluteSpace;
                
            }
            
            //iterate to the next child
            boneChild=boneChild->next;
            
        }
    }

    void U4DArmatureData::setRestPoseMatrix(){
     
        
        //YOU MUST CLEAR THE U4DMODEL FINAL ARMATURE BONE MATRIX
        u4dModel->armatureBoneMatrix.clear();
        
        //get parent bone
        U4DBoneData* boneChild = rootBone;
        
        //While there are still bones
        while (boneChild!=0) {
            
            
            if (boneChild->isRoot()) {
                
                boneChild->restAbsolutePoseSpace=boneChild->bindPoseSpace;
                
            }else{
                
                boneChild->restAbsolutePoseSpace=boneChild->bindPoseSpace*boneChild->parent->bindPoseSpace;
               
            }
            
            U4DDualQuaternion finalMatrixSpace=boneChild->inverseBindPoseSpace*boneChild->restAbsolutePoseSpace;
            
            finalMatrixSpace=finalMatrixSpace*bindShapeSpace;
            
            //convert F into a 4x4 matrix
            U4DMatrix4n finalMatrixTransform=finalMatrixSpace.transformDualQuaternionToMatrix4n();
            
            //F is then loaded into a buffer which will be sent to openGL buffer
            u4dModel->armatureBoneMatrix.push_back(finalMatrixTransform);
            
            //iterate to the next child
            boneChild=boneChild->next;
            
        }

    }

    void U4DArmatureData::setVertexWeightsAndBoneIndices(){
        
        std::vector<U4DBoneData*> dummyBoneDataContainer;
        
        for (int i=0; i<rootBone->vertexWeightContainer.size(); i++) {
            
            //clear the vertex weight output vector
            dummyBoneDataContainer.clear();
            
            //copy the temp bone containter to the boneDataContainer
            
            dummyBoneDataContainer=boneDataContainer;
            
            //Heap sort, the index i represent the current vertex weights I'm working on the bone
            
            heapSorting(dummyBoneDataContainer,i);
            
            //after the bones have been sorted, prepare bone data to send to opengl buffer
            
            prepareAndSendBoneDataToBuffer(dummyBoneDataContainer,i);
        }
        
        
    }

    void U4DArmatureData::prepareAndSendBoneDataToBuffer(std::vector<U4DBoneData*> &uBoneDataContainer,int boneVertexWeightIndex){
        
        std::vector<float> boneVertexWeights(4,0.0);
        std::vector<float> boneIndices(4,0.0);
        
        int count=0;
        
        if (uBoneDataContainer.size()>4) {
            
            //select the last four elements
            
            for (int i=uBoneDataContainer.size()-1; i>=uBoneDataContainer.size()-4; i--) {
                
                boneIndices.at(count)=uBoneDataContainer.at(i)->index;
                boneVertexWeights.at(count)=uBoneDataContainer.at(i)->vertexWeightContainer.at(boneVertexWeightIndex);
                
                count++;
            }
            
        }else{
            
            for (int i=0; i<uBoneDataContainer.size(); i++) {
                
                boneIndices.at(i)=uBoneDataContainer.at(i)->index;
                boneVertexWeights.at(i)=uBoneDataContainer.at(i)->vertexWeightContainer.at(boneVertexWeightIndex);
                
            }
        }
        
        //up to 4 because we only need info from 4 bones
        
        //load the bone vertex weights data into u4dModel
        U4DVector4n boneVertexWeightVector(boneVertexWeights.at(0),boneVertexWeights.at(1),boneVertexWeights.at(2),boneVertexWeights.at(3));
        u4dModel->bodyCoordinates.vertexWeightsContainer.push_back(boneVertexWeightVector);
            
        //load the bone indices data into the u4dModel
        U4DVector4n boneIndicesVector(boneIndices.at(0),boneIndices.at(1),boneIndices.at(2),boneIndices.at(3));
        
        u4dModel->bodyCoordinates.boneIndicesContainer.push_back(boneIndicesVector);
        
    }


    void U4DArmatureData::heapSorting(std::vector<U4DBoneData*> &uBoneDataContainer,int boneVertexWeightIndex){
        
        int index; //index of boneDataContainer element
        
        int numValues=(int)uBoneDataContainer.size();
        
        //convert the array of values into a heap
        
        for (index=numValues/2-1; index>=0; index--) {
            
            reHeapDown(uBoneDataContainer,boneVertexWeightIndex,index,numValues-1);
        }
        
        //sort the array
        for (index=numValues-1; index>=1; index--) {
            
            swap(uBoneDataContainer,0,index);
            reHeapDown(uBoneDataContainer,boneVertexWeightIndex,0,index-1);
        }
        
    }

    void U4DArmatureData::reHeapDown(std::vector<U4DBoneData*> &uBoneDataContainer,int boneVertexWeightIndex,int root, int bottom){
        
        int maxChild;
        int rightChild;
        int leftChild;
        
        leftChild=root*2+1;
        rightChild=root*2+2;
        
        if (leftChild<=bottom) {
            
            if (leftChild==bottom) {
                
                maxChild=leftChild;
                
            }else{
                
                if (uBoneDataContainer.at(leftChild)->vertexWeightContainer.at(boneVertexWeightIndex)<=uBoneDataContainer.at(rightChild)->vertexWeightContainer.at(boneVertexWeightIndex)) {
                    
                    maxChild=rightChild;
                    
                }else{
                    maxChild=leftChild;
                }
            }
            
            if (uBoneDataContainer.at(root)->vertexWeightContainer.at(boneVertexWeightIndex)<uBoneDataContainer.at(maxChild)->vertexWeightContainer.at(boneVertexWeightIndex)) {
                
                swap(uBoneDataContainer,root,maxChild);
                reHeapDown(uBoneDataContainer,boneVertexWeightIndex,maxChild,bottom);
            }
        }
        
    }



    void U4DArmatureData::swap(std::vector<U4DBoneData*> &uBoneDataContainer,int uIndex1, int uIndex2){
        
        U4DBoneData* bone1=uBoneDataContainer.at(uIndex1);
        U4DBoneData* bone2=uBoneDataContainer.at(uIndex2);
        
        uBoneDataContainer.at(uIndex1)=bone2;
        uBoneDataContainer.at(uIndex2)=bone1;
        
    }

}
