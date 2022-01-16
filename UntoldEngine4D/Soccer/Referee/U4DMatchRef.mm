//
//  U4DMatchRef.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/14/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DMatchRef.h"
#include "U4DAABB.h"
#include "U4DBall.h"
#include "U4DGameConfigs.h"
#include "Constants.h"

namespace U4DEngine {

    U4DMatchRef* U4DMatchRef::instance=nullptr;

    U4DMatchRef* U4DMatchRef::sharedInstance(){
        
        if (instance==nullptr) {
            
            instance=new U4DMatchRef();
            
        }
        
        return instance;
    }

    U4DMatchRef::U4DMatchRef():goalScored(false),ballOutOfBound(false){
        
   
    }

    U4DMatchRef::~U4DMatchRef(){
        
        
    }


    void U4DMatchRef::update(double dt){
        
        U4DVector3n ballReflectVelocity;
        bool goal=(goalPost0->isBallInsideGoalBox() || goalPost1->isBallInsideGoalBox());
        bool ballKickedOutofBound=checkIfBallOutOfBounds();
        
        if(goal){
            goalScored=true;
            ballOutOfBound=true;
        }else{
            goalScored=false;
        }

        if (ballKickedOutofBound && goalScored==false && ballOutOfBound==false) {

            computeReflectedVelocityForBall(dt);
            
        }
        
        if(!ballKickedOutofBound && !goal){
            ballOutOfBound=false;
        }
        
     
    }

    void U4DMatchRef::initMatch(U4DTeam *uTeamA, U4DTeam *uTeamB, U4DGoalPost *uGoalPost0, U4DGoalPost *uGoalPost1, U4DField *uField){
        
        field=uField;
        
        fieldAABB=field->getFieldAABB();
        
        goalPost0=uGoalPost0;
        goalPost1=uGoalPost1;
        
    }

    bool U4DMatchRef::checkIfBallOutOfBounds(){
        
        U4DBall *ball=U4DBall::sharedInstance();
        
        U4DPoint3n ballPos=ball->getAbsolutePosition().toPoint();
        U4DVector3n rayDirection=ball->getViewInDirection();
            
        U4DPoint3n ballInterpolatedPos=ballPos+rayDirection.toPoint();
            
        //test if point is within the box
        if (!fieldAABB.isPointInsideAABB(ballInterpolatedPos)) {
            ball->kineticAction->clearForce();
            
            return true;
        }
        
        return false;
        
    }

    void U4DMatchRef::computeReflectedVelocityForBall(double dt){
        
        U4DBall *ball=U4DBall::sharedInstance();
        
        U4DPoint3n ballPos=ball->getAbsolutePosition().toPoint();
        U4DVector3n rayDirection=ball->getViewInDirection();
            
        U4DPoint3n ballInterpolatedPos=ballPos+rayDirection.toPoint();
        
        U4DPoint3n closestPoint;
        fieldAABB.closestPointOnAABBToPoint(ballInterpolatedPos, closestPoint);
        ballPos.y=0.0;
        closestPoint.y=0.0;
        U4DEngine::U4DVector3n n=(ballPos+closestPoint).toVector();
        n.normalize();
        
        
        float dn = 2 * ball->kickDirection.dot(n);
        
        U4DVector3n ballReflectionVelocity=ball->kickDirection - n * dn;
        ballReflectionVelocity*=ball->kickMagnitude;
        
        ball->applyVelocity(ballReflectionVelocity,dt);
        
    }

}
