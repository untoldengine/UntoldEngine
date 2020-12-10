//
//  U4DBoundingBVH.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/7/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DBoundingBVH.h"
 
namespace U4DEngine {
    
    U4DBoundingBVH::U4DBoundingBVH(){
    
    }
    
    
    U4DBoundingBVH::~U4DBoundingBVH(){
    
    }
    
    
    U4DBoundingBVH::U4DBoundingBVH(const U4DBoundingBVH& value){
       
    }
    
    
    U4DBoundingBVH& U4DBoundingBVH::operator=(const U4DBoundingBVH& value){
        
        return *this;
    }

    void U4DBoundingBVH::updateBoundingVolume(std::vector<U4DPoint3n> &uMin,std::vector<U4DPoint3n> &uMax){
        
        int currentNumberOfAABB=numberOfAABB;
        
        bodyCoordinates.verticesContainer.clear();
        bodyCoordinates.indexContainer.clear();
        
        computeBoundingVolume(uMin, uMax);
        
        if (currentNumberOfAABB==uMin.size()) {
            
            renderManager->updateRenderingInformation();
            
        }else{
            
            renderManager->modifyRenderingInformation();
        }
        
        
    }

    void U4DBoundingBVH::computeBoundingVolume(std::vector<U4DPoint3n> &uMin,std::vector<U4DPoint3n> &uMax){
        
        numberOfAABB=(int)uMin.size();
        
        for(int i=0;i<uMin.size();i++){
            
            float width=(std::abs(uMax[i].x-uMin[i].x))/2.0;
            float height=(std::abs(uMax[i].y-uMin[i].y))/2.0;
            float depth=(std::abs(uMax[i].z-uMin[i].z))/2.0;
            
            U4DVector3n v1(width,height,depth);
            U4DVector3n v2(width,height,-depth);
            U4DVector3n v3(-width,height,-depth);
            U4DVector3n v4(-width,height,depth);
            
            U4DVector3n v5(width,-height,depth);
            U4DVector3n v6(width,-height,-depth);
            U4DVector3n v7(-width,-height,-depth);
            U4DVector3n v8(-width,-height,depth);
            
            int n=8*i;
            
            U4DIndex i1(0+n,1+n,2+n);
            U4DIndex i2(2+n,3+n,0+n);
            U4DIndex i3(4+n,5+n,6+n);
            U4DIndex i4(6+n,7+n,4+n);
            
            U4DIndex i5(5+n,6+n,2+n);
            U4DIndex i6(2+n,3+n,7+n);
            U4DIndex i7(7+n,4+n,5+n);
            U4DIndex i8(5+n,1+n,0+n);
            
            bodyCoordinates.addVerticesDataToContainer(v1);
            bodyCoordinates.addVerticesDataToContainer(v2);
            bodyCoordinates.addVerticesDataToContainer(v3);
            bodyCoordinates.addVerticesDataToContainer(v4);
            
            bodyCoordinates.addVerticesDataToContainer(v5);
            bodyCoordinates.addVerticesDataToContainer(v6);
            bodyCoordinates.addVerticesDataToContainer(v7);
            bodyCoordinates.addVerticesDataToContainer(v8);
            
            bodyCoordinates.addIndexDataToContainer(i1);
            bodyCoordinates.addIndexDataToContainer(i2);
            bodyCoordinates.addIndexDataToContainer(i3);
            bodyCoordinates.addIndexDataToContainer(i4);
            
            bodyCoordinates.addIndexDataToContainer(i5);
            bodyCoordinates.addIndexDataToContainer(i6);
            bodyCoordinates.addIndexDataToContainer(i7);
            bodyCoordinates.addIndexDataToContainer(i8);
            
        }
        
        //loadRenderingInformation();
    }
    
}
