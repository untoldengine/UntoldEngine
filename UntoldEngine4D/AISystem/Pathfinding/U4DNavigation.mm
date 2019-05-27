//
//  U4DNavigation.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/22/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "U4DNavigation.h"
#include "U4DNavMeshLoader.h"
#include "U4DNavMesh.h"
#include "U4DPathfinderAStar.h"
#include "U4DDynamicModel.h"

namespace U4DEngine {
    
    U4DNavigation::U4DNavigation():pathComputed(false){
        
        navMesh=new U4DEngine::U4DNavMesh;
        
    }
    
    U4DNavigation::~U4DNavigation(){
        
        delete navMesh;
        
    }
    
    bool U4DNavigation::loadNavMesh(const char* uNavMeshName, const char* uBlenderFile){
        
        //make sure to erase the nav mesh
        navMesh->navMeshNodeContainer.clear();
        
        U4DNavMeshLoader *navLoader=U4DNavMeshLoader::sharedInstance();
        
        if(navLoader->loadDigitalAssetFile(uBlenderFile) && navLoader->loadNavMesh(navMesh, uNavMeshName)){
        
            return true;
        }
        
        return false;
        
    }
    
    void U4DNavigation::computePath(U4DDynamicModel *uDynamicModel, U4DVector3n &uTargetPosition){
        
        //clear the path container
        path.clear();
        pathComputed=false;
        
        //set target and starting position
        targetPosition=uTargetPosition;
        
        U4DVector3n startingPosition=uDynamicModel->getAbsolutePosition();
        
        U4DPathfinderAStar pathAStar;
        
        int startingIndexNode=navMesh->getNodeIndexClosestToPosition(startingPosition);
        int targetIndexNode=navMesh->getNodeIndexClosestToPosition(targetPosition);
        
        if(pathAStar.findPath(navMesh,startingIndexNode,targetIndexNode,path)){
            
            //get the last path segment in the path
            lastPathInNavMeshIndex=(int)path.size()-1;
            
            //transform the path to the model space (y coordinate)
            for(auto &n:path){
            
                n.pointA.y=startingPosition.y;
                n.pointB.y=startingPosition.y;
                
            }
            
            pathComputed=true;
        }
        
    }
    
    U4DVector3n U4DNavigation::getSteering(U4DDynamicModel *uDynamicModel){
        
        if (pathComputed) {
            
            if (followPath.getCurrentPathIndex()!=lastPathInNavMeshIndex ) {
                
                return followPath.getSteering(uDynamicModel, path);
            
            }else{
                    
                return arrive.getSteering(uDynamicModel, targetPosition);
                
            }
            
        }else{
            return U4DVector3n(0.0,0.0,0.0);
        }
        
    }
    
    void U4DNavigation::setPredictTime(float uPredictTime){
        
        followPath.setPredictTime(uPredictTime);
    }
    
    void U4DNavigation::setPathOffset(float uPathOffset){
        
        followPath.setPathOffset(uPathOffset);
    }
    
    void U4DNavigation::setPathRadius(float uPathRadius){
        
        followPath.setPathRadius(uPathRadius);
    }
    
    void U4DNavigation::setTargetRadius(float uTargetRadius){
        
        arrive.setTargetRadius(uTargetRadius);
        
    }
    
    void U4DNavigation::setSlowRadius(float uSlowRadius){
        
        arrive.setSlowRadius(uSlowRadius);
    }
    
}
