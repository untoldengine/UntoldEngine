//
//  U4DFollowPath.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/1/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "U4DFollowPath.h"
#include "U4DDynamicModel.h"

namespace U4DEngine {
    
    U4DFollowPath::U4DFollowPath():predictTime(0.5),pathOffset(0.3),pathRadius(0.5){
        
    }
    
    U4DFollowPath::~U4DFollowPath(){
        
    }
    
    U4DVector3n U4DFollowPath::getSteering(U4DDynamicModel *uDynamicModel, std::vector<U4DSegment> &uPathContainer){
        
        U4DVector3n viewDir=uDynamicModel->getViewInDirection();
        viewDir.normalize();
        
        U4DVector3n velocity=uDynamicModel->getVelocity();
        
        //This is a special condition: if the character's velocity is equal to zero, and is close to the path at the start, the entity will not move. To make it move, set the velocity to the current view direction
        if (velocity.magnitudeSquare()==0) {
            velocity=viewDir;
        }
        
        //get the predicted future location
        
        U4DVector3n predictedPosition=uDynamicModel->getAbsolutePosition()+velocity*predictTime;
        
        U4DPoint3n predictedPositionPoint=predictedPosition.toPoint();
        
        //find the closest path to the predicted point
        float minDistanceToSegment=FLT_MAX;
        int closestSegmentIndex=0;
        
        for(int i=0;i<uPathContainer.size();i++){
            
            float distanceToSegment=uPathContainer.at(i).sqDistancePointSegment(predictedPositionPoint);
            
            if (distanceToSegment<=minDistanceToSegment) {
                minDistanceToSegment=distanceToSegment;
                closestSegmentIndex=i;
            }
            
        }
        
        //get the normal point to the closest path
        U4DSegment closestPath=uPathContainer.at(closestSegmentIndex);
        
        //set current path index
        currentPathIndex=closestSegmentIndex;
        
        U4DPoint3n pointOnPath=closestPath.closestPointOnSegmentToPoint(predictedPositionPoint);
        
        //get the magnitude of the predicted and point on path
        float distance=(predictedPositionPoint-pointOnPath).magnitude();
        
        
        if(distance<pathRadius){
            
            return U4DSeek::getSteering(uDynamicModel,predictedPosition);
            
        }else{
            
            U4DVector3n pathDirection=closestPath.pointB-closestPath.pointA;
            
            U4DVector3n pathDirectionNormalize=pathDirection;
            pathDirectionNormalize.normalize();
            
            //flip the direction character is heading the opposite direction of the vector
            if (viewDir.dot(pathDirectionNormalize)<0) {
                pathDirection*=-1.0;
            }
            
            predictedPosition=pointOnPath.toVector()+pathDirection*pathOffset;
            
        }
    
        return U4DSeek::getSteering(uDynamicModel,predictedPosition);
        
    }
    
    void U4DFollowPath::setPredictTime(float uPredictTime){
        predictTime=uPredictTime;
    }
    
    void U4DFollowPath::setPathOffset(float uPathOffset){
        pathOffset=uPathOffset;
    }
    
    void U4DFollowPath::setPathRadius(float uPathRadius){
        pathRadius=uPathRadius;
    }
    
    int U4DFollowPath::getCurrentPathIndex(){
        return currentPathIndex;
    }
    
}
