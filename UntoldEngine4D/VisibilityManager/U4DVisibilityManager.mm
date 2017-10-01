//
//  U4DVisibilityManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/30/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U4DVisibilityManager.h"
#include "U4DPlane.h"
#include "U4DBoundingAABB.h"
#include "U4DBoundingVolume.h"
#include "U4DPoint3n.h"

namespace U4DEngine {
    
    U4DVisibilityManager::U4DVisibilityManager(){
        
    }
    
    U4DVisibilityManager::~U4DVisibilityManager(){
        
    }
    
    void U4DVisibilityManager::setModelVisibility(U4DStaticModel* uModel, std::vector<U4DPlane> &uPlanes){
        
        //get the aabb of the model
        U4DBoundingVolume *aabb=uModel->getCullingPhaseBoundingVolume();
        
        if (modelInFrustum(uPlanes, aabb)) {
            
            uModel->setModelVisibility(true);
            
            std::cout<<uModel->getName()<<": Model in frustum"<<std::endl;
        }else{
            uModel->setModelVisibility(false);
            
            std::cout<<uModel->getName()<<": Model out of frustum"<<std::endl;
        }
        
        
    }
    
    bool U4DVisibilityManager::modelInFrustum(std::vector<U4DPlane> &uPlanes, U4DBoundingVolume *uAABB){
        
        U4DPoint3n minPoints=uAABB->getMinBoundaryPoint();
        U4DPoint3n maxPoints=uAABB->getMaxBoundaryPoint();
        U4DPoint3n aabbCenter=uAABB->getAbsolutePosition().toPoint();
        
        
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
    
}
