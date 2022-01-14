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

namespace U4DEngine {

    U4DMatchRef* U4DMatchRef::instance=nullptr;

    U4DMatchRef* U4DMatchRef::sharedInstance(){
        
        if (instance==nullptr) {
            
            instance=new U4DMatchRef();
            
        }
        
        return instance;
    }

    U4DMatchRef::U4DMatchRef(){
        
   
    }

    U4DMatchRef::~U4DMatchRef(){
        
        
    }

    void U4DMatchRef::setField(U4DField *uField){
        
        field=uField;
        
        fieldAABB=field->getFieldAABB();
        
    }

    void U4DMatchRef::update(double dt){
        
        U4DVector3n ballReflectVelocity;
        
        if (checkIfBallOutOfBounds()) {
            
            computeReflectedVelocityForBall(dt);
            
        }
        
    }

    void U4DMatchRef::startMatch(U4DTeam *uTeamA, U4DTeam *uTeamB){
        
        
        //outOfBoundsScheduler->scheduleClassWithMethodAndDelay(this, &U4DMatchRef::checkIfOutOfBounds, outOfBoundsTimer, 0.5,true);
    }

    bool U4DMatchRef::checkIfBallOutOfBounds(){
        
        U4DBall *ball=U4DBall::sharedInstance();
        
        U4DPoint3n ballPos=ball->getAbsolutePosition().toPoint();
        U4DVector3n rayDirection=ball->getViewInDirection();
            
        U4DPoint3n posY=ballPos+rayDirection.toPoint();
            
        //test if point is within the box
        if (!fieldAABB.isPointInsideAABB(posY)) {
            ball->kineticAction->clearForce();
            
            return true;
        }
        
        return false;
        
    }

    void U4DMatchRef::computeReflectedVelocityForBall(double dt){
        
        U4DBall *ball=U4DBall::sharedInstance();
        
        U4DPoint3n ballPos=ball->getAbsolutePosition().toPoint();
        U4DVector3n rayDirection=ball->getViewInDirection();
            
        U4DPoint3n posY=ballPos+rayDirection.toPoint();
        
        U4DPoint3n closestPoint;
        fieldAABB.closestPointOnAABBToPoint(posY, closestPoint);
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
