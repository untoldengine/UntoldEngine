//
//  U4DVisibilityCulling.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/3/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DVisibilityCulling.h"
#include "U4DPlane.h"
#include "U4DBoundingAABB.h"
#include "U4DBoundingVolume.h"
#include "U4DPoint3n.h"
#include "U4DNumerical.h"

namespace U4DEngine {
    
    U4DVisibilityCulling::U4DVisibilityCulling(){
        
    }
    
    U4DVisibilityCulling::~U4DVisibilityCulling(){
        
    }
    
    void U4DVisibilityCulling::startFrustumIntersection(std::vector<std::shared_ptr<U4DBVHNode<U4DModel>>>& uTreeContainer, std::vector<U4DPlane> &uPlanes){
        
        //get root tree
        U4DBVHNode<U4DModel> *child=uTreeContainer.at(0).get()->next;
        
        if (child->getModelsContainer().size()>1) {
            
            testFrustumIntersection(child->getFirstChild(), child->getLastChild(), uPlanes);
            
        }else if (child->getModelsContainer().size()==1){
            
            //if the tree only has one item
            testFrustumIntersection(nullptr, child->lastDescendant, uPlanes);
            
        }
        
        
    }
    
    bool U4DVisibilityCulling::aabbInFrustum(std::vector<U4DPlane> &uPlanes, U4DAABB *uAABB){
        
        U4DPoint3n minPoints=uAABB->getMinPoint();
        U4DPoint3n maxPoints=uAABB->getMaxPoint();
        
        for(int i=0; i<6; i++){
            
            int outOfFrustum=0;
            
            U4DVector3n planeNormal=uPlanes.at(i).n;
            float d=uPlanes.at(i).d;
            
            U4DVector4n plane(planeNormal.x,planeNormal.y,planeNormal.z,d);
            
            //check if all the points of the AABB intersect or are inside the plane
            
            outOfFrustum+=((plane.dot(U4DVector4n(minPoints.x,minPoints.y,minPoints.z,1.0))<0.0)?1:0);
            outOfFrustum+=((plane.dot(U4DVector4n(maxPoints.x,minPoints.y,minPoints.z,1.0))<0.0)?1:0);
            outOfFrustum+=((plane.dot(U4DVector4n(minPoints.x,maxPoints.y,minPoints.z,1.0))<0.0)?1:0);
            outOfFrustum+=((plane.dot(U4DVector4n(maxPoints.x,maxPoints.y,minPoints.z,1.0))<0.0)?1:0);
            
            outOfFrustum+=((plane.dot(U4DVector4n(minPoints.x,minPoints.y,maxPoints.z,1.0))<0.0)?1:0);
            outOfFrustum+=((plane.dot(U4DVector4n(maxPoints.x,minPoints.y,maxPoints.z,1.0))<0.0)?1:0);
            outOfFrustum+=((plane.dot(U4DVector4n(minPoints.x,maxPoints.y,maxPoints.z,1.0))<0.0)?1:0);
            outOfFrustum+=((plane.dot(U4DVector4n(maxPoints.x,maxPoints.y,maxPoints.z,1.0))<0.0)?1:0);
            
            if (outOfFrustum==8) {
                
                return false;
            }
            
        }
        
        return true;
    }
    
    void U4DVisibilityCulling::testFrustumIntersection(U4DBVHNode<U4DModel> *uTreeLeftNode, U4DBVHNode<U4DModel> *uTreeRightNode, std::vector<U4DPlane> &uPlanes){
        
        if(uTreeLeftNode==NULL && uTreeRightNode==NULL) return;
        
        
        if (uTreeLeftNode!=nullptr) {
            U4DAABB *leftAABB=uTreeLeftNode->getAABBVolume();
            
            //analyze left node
            if (uTreeLeftNode->isLeaf()) {
                
                U4DModel *model=uTreeLeftNode->getModelsContainer().at(0);
                
                if (model!=nullptr) {
                    
                    U4DBoundingVolume *aabbBoundingVolume=model->getCullingPhaseBoundingVolume();
                    
                    U4DPoint3n maxPoint=aabbBoundingVolume->getMaxBoundaryPoint();
                    U4DPoint3n minPoint=aabbBoundingVolume->getMinBoundaryPoint();
                    
                    U4DAABB aabb;
                    
                    aabb.setMaxPoint(maxPoint);
                    aabb.setMinPoint(minPoint);
                    
                    if (aabbInFrustum(uPlanes, &aabb)) {
                        
                        model->setModelVisibility(true);
                        
                    }
                    
                }
                
            }else{
                
                if (aabbInFrustum(uPlanes, leftAABB)) {
                    
                    testFrustumIntersection(uTreeLeftNode->getFirstChild(), uTreeLeftNode->getLastChild(), uPlanes);
                }
                
            }
            
        }
        
        
        if (uTreeRightNode!=nullptr) {
            
            U4DAABB *rightAABB=uTreeRightNode->getAABBVolume();
            
            //analyze right node
            if (uTreeRightNode->isLeaf()) {
                
                U4DModel *model=uTreeRightNode->getModelsContainer().at(0);
                
                if (model!=nullptr) {
                    
                    U4DBoundingVolume *aabbBoundingVolume=model->getCullingPhaseBoundingVolume();
                    
                    U4DPoint3n maxPoint=aabbBoundingVolume->getMaxBoundaryPoint();
                    U4DPoint3n minPoint=aabbBoundingVolume->getMinBoundaryPoint();
                    
                    U4DAABB aabb;
                    
                    aabb.setMaxPoint(maxPoint);
                    aabb.setMinPoint(minPoint);
                    
                    if (aabbInFrustum(uPlanes, &aabb)) {
                        
                        model->setModelVisibility(true);
                        
                    }
                    
                }
                
            }else{
                
                if (aabbInFrustum(uPlanes, rightAABB)) {
                    
                    testFrustumIntersection(uTreeRightNode->getFirstChild(), uTreeRightNode->getLastChild(), uPlanes);
                }
                
            }
            
        }
        
    }
    
}
