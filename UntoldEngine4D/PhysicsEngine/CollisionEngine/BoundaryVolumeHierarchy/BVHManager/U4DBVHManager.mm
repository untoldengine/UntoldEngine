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
#include <cmath>


namespace U4DEngine{
    
    U4DBVHManager::U4DBVHManager(){
        
    }
    
    U4DBVHManager::~U4DBVHManager(){
        
    }
    
    void U4DBVHManager::buildBVH(){
        
        //1. Create node with current objects
        
        
        //2. Calculate volume
        
        //3. get longest dimension
        
        //4. sort objects along the longest dimension
        
        //5. get split index
        
        //6. build left and right node
        
        //
        
    }
    
    void U4DBVHManager::buildBVHNode(){
        
    }
    
    void U4DBVHManager::sortModels(U4DBVHTree *uNode){
        
    }
    
    void U4DBVHManager::calculateBVHVolume(U4DBVHTree *uNode){
        
        float xMin=0.0;
        float xMax=0.0;
        float yMin=0.0;
        float yMax=0.0;
        float zMin=0.0;
        float zMax=0.0;
        
        //get the min and max points for the volume
        
        for (auto n:uNode->models) {
        
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
        uNode->setBoundaryVolumeMaxPoint(maxPoint);
        
        U4DPoint3n minPoint(xMin,yMin,zMin);
        uNode->setBoundaryVolumeMinPoint(minPoint);
        
    }
    
    void U4DBVHManager::getBVHLongestDimensionVector(U4DBVHTree *uNode){
        
        //get the longest dimension of the volume
        float xDimension=std::abs(uNode->getBoundaryVolumeMinPoint().x-uNode->getBoundaryVolumeMaxPoint().x);
        float yDimension=std::abs(uNode->getBoundaryVolumeMinPoint().y-uNode->getBoundaryVolumeMaxPoint().y);
        float zDimension=std::abs(uNode->getBoundaryVolumeMinPoint().z-uNode->getBoundaryVolumeMaxPoint().z);
        
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
        
         uNode->setLongestVolumeDimensionVector(longestDimensionVector);
        
    }
    
    void U4DBVHManager::getBVHSplitIndex(U4DBVHTree *uNode){
        
    }
    
    void U4DBVHManager::addModel(U4DDynamicModel* uModel){
        
        models.push_back(uModel);
        
    }
    
    void U4DBVHManager::clearModels(){
        
        models.clear();
        
    }
    
}