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
#include "U4DTeamStateIdle.h"
#include "U4DTeamStateGoHome.h"
#include "U4DTeamStateReady.h"
#include "U4DMessageDispatcher.h"
#include <iterator>

namespace U4DEngine {

    U4DMatchManager* U4DMatchManager::instance=0;

    U4DMatchManager* U4DMatchManager::sharedInstance(){
        
        if (instance==0) {
            
            instance=new U4DMatchManager();
            
        }
        
        return instance;
    }

    U4DMatchManager::U4DMatchManager():ballOutOfBound(false),state(-1),teamAScore(0),teamBScore(0),elapsedClockTime(0){
        
        teamA=new U4DTeam("TeamA");
        teamB=new U4DTeam("TeamB");
        
        //Create the callback. Notice that you need to provide the name of the class
        endGameScheduler=new U4DEngine::U4DCallback<U4DMatchManager>;

        //create the timer
        endGameTimer=new U4DEngine::U4DTimer(endGameScheduler);
        
        //Create the callback. Notice that you need to provide the name of the class
        startGameScheduler=new U4DEngine::U4DCallback<U4DMatchManager>;

        //create the timer
        startGameTimer=new U4DEngine::U4DTimer(startGameScheduler);
        
        
    }

    U4DMatchManager::~U4DMatchManager(){
        
        
        startGameScheduler->unScheduleTimer(startGameTimer);
        delete startGameScheduler;
        delete startGameTimer;
        
        endGameScheduler->unScheduleTimer(endGameTimer);
        delete endGameScheduler;
        delete endGameTimer;
        
    }


    void U4DMatchManager::update(double dt){
        
        if(teamA!=nullptr){
            teamA->update(dt);
        }
        
        if(teamB!=nullptr){
            teamB->update(dt);
        }
        
        if(state==playing){
            
            if((teamAGoalPost->isBallInsideGoalBox() || teamBGoalPost->isBallInsideGoalBox())){
                
                U4DBall *ball=U4DEngine::U4DBall::sharedInstance();
                ball->changeState(U4DEngine::decelerating);
                
                changeState(goalScored);
                
            }else if(checkIfBallOutOfBounds()){
             
                changeState(outOfBound);
            }
            
        }else if(state==goalScored){
            
            //find out who score
            U4DBall *ball=U4DEngine::U4DBall::sharedInstance();
            
            
            if(ball->getBallInsideGoalPost()==teamAGoalPost){
                //team B scored. Update score
                
                teamAScore++;
                
                
                
            }else if(ball->getBallInsideGoalPost()==teamBGoalPost){
                //team A scored. Update score
                
                teamBScore++;
            }
            
            
            //update the score
            
            ball->insideGoalPost(nullptr);
            
            changeState(sendTeamsHome);
            
        }else if(state==outOfBound){

            //computeReflectedVelocityForBall(dt);
            
            //changeState(throwIn);
            changeState(sendTeamsHome);
        }else if(state==throwIn){
            
            //This is only a temp soln.
            if(!checkIfBallOutOfBounds()){
                changeState(playing);
            }
            
        }else if(state==sendTeamsHome){
            
            //nofity teams to change their states to 'going home'
            teamA->changeState(U4DTeamStateGoHome::sharedInstance());
            teamB->changeState(U4DTeamStateGoHome::sharedInstance());
            U4DBall *ball=U4DEngine::U4DBall::sharedInstance();
            
            ball->translateTo(ball->homePosition);
            ball->changeState(stopped);
            
            changeState(teamsGettingReady);
            
        }else if(state==teamsGettingReady){
            
            if(teamA->getCurrentState()==U4DTeamStateReady::sharedInstance() && teamB->getCurrentState()==U4DTeamStateReady::sharedInstance()){
                
                U4DMessageDispatcher *messageDispatcher=U4DMessageDispatcher::sharedInstance();
                
                messageDispatcher->sendMessage(0.0, teamA, msgTeamStart);
                messageDispatcher->sendMessage(0.0, teamB, msgTeamStart);
                
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

    void U4DMatchManager::initMatchTimer(int uEndTime, int uFrequency){
        
        endClockTime=uEndTime;
        
        endGameScheduler->scheduleClassWithMethodAndDelay(this, &U4DMatchManager::timesUp, endGameTimer,uFrequency, true);
        
    }

    void U4DMatchManager::timesUp(){
        
        elapsedClockTime++;

        if(elapsedClockTime>=endClockTime){
            state=gameTimeReached;
        }
        
    }

    void U4DMatchManager::initMatchElements(U4DGoalPost *uTeamAGoalPost, U4DGoalPost *uTeamBGoalPost, U4DField *uField){
        
        field=uField;
        
        fieldAABB=field->getFieldAABB();
        
        teamAGoalPost=uTeamAGoalPost;
        teamBGoalPost=uTeamBGoalPost;
        
        teamA->loadPlayersFormations();
        teamB->loadPlayersFormations();
        
        teamA->initAnalyzerSchedulers();
        teamB->initAnalyzerSchedulers();
        
        teamA->setOppositeTeam(teamB);
        teamB->setOppositeTeam(teamA);
        
        teamA->changeState(U4DEngine::U4DTeamStateReady::sharedInstance());
        teamB->changeState(U4DEngine::U4DTeamStateReady::sharedInstance());
        
        //init a timer of 3 seconds
        startGameScheduler->scheduleClassWithMethodAndDelay(this, &U4DMatchManager::startGame, startGameTimer,1.0, false);
        

    }

    void U4DMatchManager::startGame(){
        
        U4DMessageDispatcher *messageDispatcher=U4DMessageDispatcher::sharedInstance();
        
        messageDispatcher->sendMessage(0.0, teamA, msgTeamStart);
        messageDispatcher->sendMessage(0.0, teamB, msgTeamStart);
        
        changeState(playing);
        
        
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
                
            case restartGame:
                
                break;
        }
    }

    U4DGoalPost *U4DMatchManager::getTeamAGoalPost(){
        return teamAGoalPost;
    }

    U4DGoalPost *U4DMatchManager::getTeamBGoalPost(){
        return teamBGoalPost;
    }

    int U4DMatchManager::getElapsedGameTime(){
        return elapsedClockTime;
    }

    std::vector<int> U4DMatchManager::getCurrentScore(){
        std::vector<int> currentScore{teamAScore,teamBScore};
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
