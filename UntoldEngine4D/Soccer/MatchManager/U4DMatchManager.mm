//
//  U4DMatchManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/14/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DMatchManager.h"
#include "U4DAABB.h"
#include "U4DBall.h"
#include "U4DGameConfigs.h"
#include "Constants.h"
#include "CommonProtocols.h"

#include "U4DTeamStateAttacking.h"
#include "U4DTeamStateDefending.h"

namespace U4DEngine {

    U4DMatchManager* U4DMatchManager::instance=nullptr;

    U4DMatchManager* U4DMatchManager::sharedInstance(){
        
        if (instance==nullptr) {
            
            instance=new U4DMatchManager();
            
        }
        
        return instance;
    }

    U4DMatchManager::U4DMatchManager():ballOutOfBound(false){
        
   
    }

    U4DMatchManager::~U4DMatchManager(){
        
        
    }


    void U4DMatchManager::update(double dt){
        
        if(teamA!=nullptr){
            teamA->update(dt);
        }
        
        if(teamB!=nullptr){
            teamB->update(dt);
        }
        
        if(state==playing){
            
            if((goalPost0->isBallInsideGoalBox() || goalPost1->isBallInsideGoalBox())){
                //goalScored=true;
                
                U4DBall *ball=U4DEngine::U4DBall::sharedInstance();
                ball->changeState(U4DEngine::decelerating);
                
                changeState(goalScored);
                
            }else if(checkIfBallOutOfBounds()){
             
                changeState(outOfBound);
            }
            
        }else if(state==goalScored){
            
            //This is only a temp soln.
            if(!checkIfBallOutOfBounds()){
                changeState(playing);
            }
            
        }else if(state==outOfBound){

            computeReflectedVelocityForBall(dt);
            
            changeState(throwIn);
        
        }else if(state==throwIn){
            
            //This is only a temp soln.
            if(!checkIfBallOutOfBounds()){
                changeState(playing);
            }
            
        }
        
        
        
        
        
//        if((checkIfBallOutOfBounds() && (goalPost0->distanceOfBallToGoalPost()<=1.0 || goalPost1->distanceOfBallToGoalPost()<=1.0)) || goalScored==true){
//            ballOutOfBound=false;
//        }else if(checkIfBallOutOfBounds() && goalScored==false){
//            ballOutOfBound=true;
//        }else{
//            ballOutOfBound=false;
//        }
        
//        if((goalPost0->isBallInsideGoalBox() || goalPost1->isBallInsideGoalBox()) && goalScored==false){
//
//            goalScored=true;
//
//        }else{
//            goalScored=false;
//        }
//
//        if (checkIfBallOutOfBounds() && goalScored==false && ballOutOfBound==false) {
//
//            ballOutOfBound=true;
//
//
//        }else{
//            ballOutOfBound=false;
//        }
        
        
        
     
    }

    void U4DMatchManager::initMatch(U4DTeam *uTeamA, U4DTeam *uTeamB, U4DGoalPost *uGoalPost0, U4DGoalPost *uGoalPost1, U4DField *uField){
        
        field=uField;
        
        fieldAABB=field->getFieldAABB();
        
        goalPost0=uGoalPost0;
        goalPost1=uGoalPost1;
        
        teamA=uTeamA;
        teamB=uTeamB;
        
        teamA->updateFormation();
        teamA->initAnalyzerSchedulers();
        
        teamB->updateFormation();
        teamB->initAnalyzerSchedulers();
        
        teamA->setOppositeTeam(teamB);
        teamB->setOppositeTeam(teamA);
        
        teamA->changeState(U4DEngine::U4DTeamStateAttacking::sharedInstance());
        teamB->changeState(U4DEngine::U4DTeamStateDefending::sharedInstance());
        
    }

    void U4DMatchManager::setState(int uState){
        state=uState;
    }

    int U4DMatchManager::getState(){
        return state;
    }

    void U4DMatchManager::changeState(int uState){
        
        state=uState;
        
        switch(uState){
                
            case playing:
                
                break;
                
            case outOfBound: 
                
                break;
                
            case throwIn:
                
                break;
                
            case goalScored:
                
                break;
                
            case restarting:
                
                break;
        }
    }

    bool U4DMatchManager::checkIfBallOutOfBounds(){
        
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

    void U4DMatchManager::computeReflectedVelocityForBall(double dt){
        
        
        U4DBall *ball=U4DBall::sharedInstance();
        
        U4DPoint3n ballPos=ball->getAbsolutePosition().toPoint();
        U4DVector3n rayDirection=ball->getViewInDirection();
            
        U4DPoint3n ballInterpolatedPos=ballPos+rayDirection.toPoint();
        
        //the reflected vector is computed as follows:
        //v2 = v1 – 2(v1.n)n
        //where v1 is the input vector, n is the normal vector and v2 is the reflected vector
        
        U4DPoint3n closestPoint;
        fieldAABB.closestPointOnAABBToPoint(ballInterpolatedPos, closestPoint);
        ballPos.y=0.0;
        closestPoint.y=0.0;
        
        U4DEngine::U4DVector3n n=(ballPos+closestPoint).toVector();
        n.normalize();
        
        U4DVector3n v1=ball->motionAccumulator;
        
        float vDotN = 2 * v1.dot(n);
        
        U4DVector3n v2=v1 - n*vDotN;
        
        //v2*=ball->kickMagnitude;
        
        ball->applyVelocity(v2,dt);
        
    }

}
