//
//  U4DGoalPost.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/14/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DGoalPost.h"
#include "Constants.h"
#include "U4DBall.h"

namespace U4DEngine{

    U4DGoalPost::U4DGoalPost():goalBoxComputed(false){
        
    }

    U4DGoalPost::~U4DGoalPost(){
        
    }

    //init method. It loads all the rendering information among other things.
    bool U4DGoalPost::init(const char* uModelName){
        
        if (loadModel(uModelName)) {
            
            
            loadRenderingInformation();
            
            return true;
        }
        
        return false;
        
    }

    void U4DGoalPost::update(double dt){
        
    }
    
    bool U4DGoalPost::isBallInsideGoalBox(){
        
        //if the goal post box hasn't been computed, then get its aabb
        if(!goalBoxComputed){
            
            U4DVector3n goalBoxDimensions=getModelDimensions()*0.5;
    
            U4DPoint3n center=getAbsolutePosition().toPoint();
            
            U4DAABB tempGoalBoxAABB(goalBoxDimensions.x,goalBoxDimensions.y,goalBoxDimensions.z,center);
            
            goalBoxAABB=tempGoalBoxAABB;
            
            goalBoxComputed=true;
            
        }
        
        U4DBall *ball=U4DBall::sharedInstance();
        
        U4DPoint3n ballPos=ball->getAbsolutePosition().toPoint();
        U4DVector3n rayDirection=ball->getViewInDirection();
            
        U4DPoint3n ballInterpolatedPos=ballPos+rayDirection.toPoint();
        
        if (goalBoxAABB.isPointInsideAABB(ballInterpolatedPos)) {
            
            ball->insideGoalPost(this);
            //ball is inside the goal post
            return true;
        }
        
        //ball is outside the goal post
        return false;
    
    }

    float U4DGoalPost::distanceOfBallToGoalPost(){
        
        U4DPoint3n closestPoint;
        U4DBall *ball=U4DBall::sharedInstance();
        
        U4DPoint3n ballPos=ball->getAbsolutePosition().toPoint();
        U4DVector3n rayDirection=ball->getViewInDirection();
            
        U4DPoint3n ballInterpolatedPos=ballPos+rayDirection.toPoint();
        
        goalBoxAABB.closestPointOnAABBToPoint(ballInterpolatedPos, closestPoint);
        
        return (ballPos-closestPoint).magnitude();
        
    }

}
