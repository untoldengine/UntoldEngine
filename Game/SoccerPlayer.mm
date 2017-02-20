//
//  SoccerPlayer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/30/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayer.h"
#include "UserCommonProtocols.h"
#include "SoccerPlayerStateManager.h"
#include "SoccerPlayerStateInterface.h"
#include "SoccerPlayerIdleState.h"
#include "SoccerPlayerChaseBallState.h"
#include "SoccerPlayerDribbleState.h"
#include "SoccerBall.h"

SoccerPlayer::SoccerPlayer():buttonAPressed(false),buttonBPressed(false),joystickActive(false){
    
    stateManager=new SoccerPlayerStateManager(this);
    
}
SoccerPlayer::~SoccerPlayer(){
    
    delete stateManager;
    
}

void SoccerPlayer::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        forwardKickAnimation=new U4DEngine::U4DAnimation(this);
        walkingAnimation=new U4DEngine::U4DAnimation(this);
        runningAnimation=new U4DEngine::U4DAnimation(this);
        
        groundPassAnimation=new U4DEngine::U4DAnimation(this);
        forwardCarryAnimation=new U4DEngine::U4DAnimation(this);
        sideCarryRightAnimation=new U4DEngine::U4DAnimation(this);
        sideCarryLeftAnimation=new U4DEngine::U4DAnimation(this);
        idleAnimation=new U4DEngine::U4DAnimation(this);
        takingBallControlAnimation=new U4DEngine::U4DAnimation(this);
        
        //set collision info
        initMass(80.0);
        initCoefficientOfRestitution(0.9);
        //enableCollisionBehavior();
        enableKineticsBehavior();
        
        //set gravity to zero
        U4DEngine::U4DVector3n zeroGravity(0.0,0.0,0.0);
        setGravity(zeroGravity);
        
        //set collision filters
        //setCollisionFilterCategory(kSoccerPlayer);
        //setCollisionFilterMask(kSoccerBall);
        
        //set player collision with ball filter to occur
        setCollisionFilterGroupIndex(kZeroGroupIndex);
        
        U4DEngine::U4DVector3n viewDirectionVector(0,0,1);
        
        setEntityForwardVector(viewDirectionVector);
        
        if (loadAnimationToModel(walkingAnimation, "walking", "walkinganimationscript.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(forwardKickAnimation, "forwardkick", "forwardkickanimationscript.u4d")) {

            
            
        }
        
        if (loadAnimationToModel(runningAnimation, "running", "runninganimationscript.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(groundPassAnimation, "sidepass", "sidepassanimationscript.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(forwardCarryAnimation, "forwardcarry", "forwardcarryanimationscript.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(sideCarryLeftAnimation, "sidecarryleft", "sidecarryleftanimationscript.u4d")) {
            
            
            
        }

        if (loadAnimationToModel(sideCarryRightAnimation, "sidecarryright", "sidecarryrightanimationscript.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(idleAnimation, "idle", "idleanimationscript.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(takingBallControlAnimation, "takingballcontrol", "takingballcontrolanimationscript.u4d")) {
            
            
            
        }
        
        SoccerPlayerStateInterface *chaseBallState=SoccerPlayerChaseBallState::sharedInstance();
        SoccerPlayerStateInterface *idleState=SoccerPlayerIdleState::sharedInstance();
        
        //set initial state
        changeState(chaseBallState);
        
        //render information
        loadRenderingInformation();
        
        //translate the player
        translateBy(-9.0, getModelDimensions().y/2.0+1.3, 0.0);
        
    }
    
    
    
}

void SoccerPlayer::setPlayerHeading(U4DEngine::U4DVector3n& uHeading){
    
    //set view heading of player
    viewInDirection(uHeading);
    
}

U4DEngine::U4DVector3n SoccerPlayer::getPlayerHeading(){
    
    U4DEngine::U4DVector3n heading=getViewInDirection();
    
    heading.x*=fieldLength;
    heading.z*=fieldWidth;
    
    return heading;
    
}

void SoccerPlayer::update(double dt){
    
    stateManager->execute(dt);
    
    /*
    //check if model has collided with ball
    if (getModelHasCollided()) {
        
        U4DEngine::U4DVector3n view=getViewInDirection();
        
        U4DEngine::U4DVector3n relativePositionOfBall=soccerBallEntity->getAbsolutePosition()-getAbsolutePosition();
        
        view.normalize();
        relativePositionOfBall.normalize();
        
        float inSameDirection=view.dot(relativePositionOfBall);
        
        if (inSameDirection>=0) {
            
            //set player collision with ball filter not to occur
            setCollisionFilterGroupIndex(kNegativeGroupIndex);
            changeState(kGroundPass);
            
        }else{
            //apply collision with ball
            setCollisionFilterGroupIndex(kZeroGroupIndex);
            changeState(kNull);
        }
        
    }
    

    if (getState()==kWalking) {
        
        if (getIsAnimationUpdatingKeyframe()&&getAnimationCurrentInterpolationTime()==0) {
            
            float velocity=5.0;
            
            applyForceToPlayer(velocity, dt);
        
        }
        
    }else if (getState()==kRunning) {
        
        if (getIsAnimationUpdatingKeyframe()&&getAnimationCurrentInterpolationTime()==0) {
            
            float velocity=10.0;
            
            applyForceToPlayer(velocity, dt);
            
        }
            
    }else if (getState()==kInPossesionOfBall) {
        
        
    }else if (getState()==kAdvancingWithBall){
    
        
    }else if (getState()==kGroundPass) {
        
        if (getIsAnimationUpdatingKeyframe()) {
            
            //set the kick pass at this keyframe and interpolation time
            if (getAnimationCurrentKeyframe()==3 && getAnimationCurrentInterpolationTime()==0) {
                
                joyStickData.normalize();
                soccerBallEntity->changeState(kGroundPass);
                soccerBallEntity->setKickDirection(joyStickData);
                
                //apply collision with ball
                //setCollisionFilterGroupIndex(kZeroGroupIndex);
                
                changeState(kRunning);
            }
        }
        
    }
    */
}



void SoccerPlayer::changeState(SoccerPlayerStateInterface* uState){
    
    stateManager->changeState(uState);
    
 /*
    removeCurrentPlayingAnimation();
    
    setState(uState);
    
    switch (uState) {
            
        case kWalking:
            
            setNextAnimationToPlay(walking);
            setPlayBlendedAnimation(true);
            
            break;
            
        case kRunning:
            
            setNextAnimationToPlay(running);
            setPlayBlendedAnimation(true);
            
            break;
            
        case kAirPass:
            
            break;
            
        case kGroundPass:
        {
            setNextAnimationToPlay(sidePass);
            setPlayNextAnimationContinuously(false);
            setPlayBlendedAnimation(true);
        }
            
            break;
            
        case kInPossesionOfBall:
            
            break;
            
        case kNull:
            
            removeAllAnimations();
            
            break;
            
        default:
            
            break;
    }
    
    playAnimation();
    
*/
}


void SoccerPlayer::trackBall(){
    
    U4DEngine::U4DVector3n ballPosition=soccerBallEntity->getAbsolutePosition();
    
    U4DEngine::U4DVector3n playerPosition=getAbsolutePosition();
    
    U4DEngine::U4DVector3n distanceVector=ballPosition-playerPosition;
    
    U4DEngine::U4DVector3n directionToLook(distanceVector.x*fieldLength,playerPosition.y,distanceVector.z*fieldWidth);
    
    viewInDirection(directionToLook);
    
}

void SoccerPlayer::setBallEntity(SoccerBall *uSoccerBall){
    
    soccerBallEntity=uSoccerBall;
}

SoccerBall *SoccerPlayer::getBallEntity(){
    
    return soccerBallEntity;
}

void SoccerPlayer::applyForceToPlayer(float uVelocity, double dt){
    
    U4DEngine::U4DVector3n heading=getViewInDirection();
    
    heading.normalize();
    
    U4DEngine::U4DVector3n forceToPlayer=(heading*uVelocity*getMass())/dt;
    
    addForce(forceToPlayer);
    
    U4DEngine::U4DVector3n initialVelocity(0.0,0.0,0.0);
    
    setVelocity(initialVelocity);
    
}

float SoccerPlayer::distanceToBall(){
    
    U4DEngine::U4DVector3n ballPosition=soccerBallEntity->getAbsolutePosition();
    
    U4DEngine::U4DVector3n playerPosition=getAbsolutePosition();
    
    //set the height position equal to the ball y position
    playerPosition.y=ballPosition.y;
    
    float ballRadius=soccerBallEntity->getBallRadius();
    
    float distance=(ballPosition-playerPosition).magnitude();
    
    return distance;
}

bool SoccerPlayer::hasReachedTheBall(){
    
    U4DEngine::U4DVector3n ballPosition=soccerBallEntity->getAbsolutePosition();
    
    U4DEngine::U4DVector3n playerPosition=getAbsolutePosition();
   
    //set the height position equal to the ball y position
    playerPosition.y=ballPosition.y;
    
    float ballRadius=soccerBallEntity->getBallRadius();
    
    float distanceToBall=(ballPosition-playerPosition).magnitude();
    
    if (distanceToBall<=(ballRadius+2.5)) {
        
        return true;
    }
    
    return false;
    
}

U4DEngine::U4DAnimation *SoccerPlayer::getRunningAnimation(){
    return runningAnimation;
}

U4DEngine::U4DAnimation *SoccerPlayer::getGroundPassAnimation(){
 
    return groundPassAnimation;
}

U4DEngine::U4DAnimation *SoccerPlayer::getForwardCarryAnimation(){
    
    return forwardCarryAnimation;
}

U4DEngine::U4DAnimation *SoccerPlayer::getIdleAnimation(){
    
    return idleAnimation;
    
}

U4DEngine::U4DAnimation *SoccerPlayer::getTakingBallControlAnimation(){
    
    return takingBallControlAnimation;
}

void SoccerPlayer::receiveTouchUpdate(bool uButtonAPressed, bool uButtonBPressed, bool uJoystickActive){
    
    buttonAPressed=uButtonAPressed;
    buttonBPressed=uButtonBPressed;
    joystickActive=uJoystickActive;
    
}

void SoccerPlayer::setButtonAPressed(bool uValue){
    
    buttonAPressed=uValue;
}

void SoccerPlayer::setButtonBPressed(bool uValue){
    
    buttonBPressed=uValue;
}

bool SoccerPlayer::getButtonAPressed(){
 
    return buttonAPressed;
}

bool SoccerPlayer::getButtonBPressed(){
    
    return buttonBPressed;
}

void SoccerPlayer::setJoystickActive(bool uValue){
    
    joystickActive=uValue;
}

bool SoccerPlayer::getJoystickActive(){
    
    return joystickActive;
}

void SoccerPlayer::removeKineticForces(){
    
    clearForce();
    clearMoment();
    
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    setVelocity(zero);
    setAngularVelocity(zero);
}

void SoccerPlayer::kickBallToGround(float uVelocity, U4DEngine::U4DVector3n uDirection, double dt){
    
    soccerBallEntity->kickBallToGround(uVelocity, uDirection, dt);
}

void SoccerPlayer::setJoystickDirection(U4DEngine::U4DVector3n uJoystickDirection){
    
    joystickDirection=uJoystickDirection;
}

U4DEngine::U4DVector3n SoccerPlayer::getJoystickDirection(){
    
    return joystickDirection;

}
