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
#include "U4DDynamicAction.h"

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
    
    void U4DNavigation::computePath(U4DDynamicAction *uAction, U4DVector3n &uTargetPosition){
        
        //clear the path container
        path.clear();
        pathComputed=false;
        
        //set target and starting position
        targetPosition=uTargetPosition;
        
        U4DVector3n startingPosition=uAction->model->getAbsolutePosition();
        
        U4DPathfinderAStar pathAStar;
        
        //get a copy of the nav mesh node container. Don't pass a reference to the path A star algo since the algo have to modify the mesh content.
        //to avoid issues don't pass the container by reference in the method findPath() shown below.
        std::vector<U4DNavMeshNode> tempNavMeshNodeContainer=navMesh->getNavMeshNodeContainer();
        
        int startingIndexNode=navMesh->getNodeIndexClosestToPosition(startingPosition);
        int targetIndexNode=navMesh->getNodeIndexClosestToPosition(targetPosition);
        
        if(pathAStar.findPath(tempNavMeshNodeContainer,startingIndexNode,targetIndexNode,path)){
            
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
    
    U4DVector3n U4DNavigation::getSteering(U4DDynamicAction *uAction){
        
        if (pathComputed) {
            
            if (followPath.getCurrentPathIndex()!=lastPathInNavMeshIndex ) {
                
                return followPath.getSteering(uAction, path);
            
            }else{
                    
                return arrive.getSteering(uAction, targetPosition);
                
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
    
    void U4DNavigation::setNavigationSpeed(float uNavigationSpeed){
        
        followPath.setMaxSpeed(uNavigationSpeed);
        
    }

    U4DNavMesh *U4DNavigation::getNavMesh(){
        return navMesh;
    }

    std::vector<U4DSegment> U4DNavigation::getNavPath(){
        
        //Because we use the Steering Behavior Arrive to slowly navigate the entity to its final position,
        //I've broken down the path into two. Therefore, we need to append the final target position as a path to the final path computed. See getSteering() to see the reason. 99% of the path is driven by the FollowPath behavior, the last 1% is driven by the Arrive behavior.
        
        std::vector<U4DSegment> totalPath=path;
        
        //get last segment in the path
        int pathSize=(int)path.size();
        
        U4DSegment preLastPathSegment=path.at(pathSize-1);
        
        //get point B in last segment
        U4DPoint3n pointB=preLastPathSegment.pointB;
        
        //create final path
        U4DPoint3n targetPositionPoint=targetPosition.toPoint();
        
        U4DSegment lastPath(pointB,targetPositionPoint);
        
        totalPath.push_back(lastPath);
        
        return totalPath;
        
    }
    
}
