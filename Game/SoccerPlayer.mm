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
#include "SoccerPlayerGroundPassState.h"
#include "SoccerBall.h"
#include "SoccerPlayerExtremity.h"
#include "U4DTrigonometry.h"
#include "U4DBoneData.h"

SoccerPlayer::SoccerPlayer():buttonAPressed(false),buttonBPressed(false),joystickActive(false),flagToPassBall(false){
    
    stateManager=new SoccerPlayerStateManager(this);
    
}
SoccerPlayer::~SoccerPlayer(){
    
    delete stateManager;
    
}

void SoccerPlayer::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        walkingAnimation=new U4DEngine::U4DAnimation(this);
        runningAnimation=new U4DEngine::U4DAnimation(this);
        
        forwardCarryAnimation=new U4DEngine::U4DAnimation(this);
        sideCarryRightAnimation=new U4DEngine::U4DAnimation(this);
        sideCarryLeftAnimation=new U4DEngine::U4DAnimation(this);
        idleAnimation=new U4DEngine::U4DAnimation(this);
        haltBallWithRightFootAnimation=new U4DEngine::U4DAnimation(this);
        haltBallWithLeftFootAnimation=new U4DEngine::U4DAnimation(this);
        rightFootSidePassAnimation=new U4DEngine::U4DAnimation(this);
        leftFootSidePassAnimation=new U4DEngine::U4DAnimation(this);
        rightFootForwardKickAnimation=new U4DEngine::U4DAnimation(this);
        leftFootForwardKickAnimation=new U4DEngine::U4DAnimation(this);
        reverseBallWithRightFootAnimation=new U4DEngine::U4DAnimation(this);
        reverseBallWithLeftFootAnimation=new U4DEngine::U4DAnimation(this);
        
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
        
        //add right foot as a child
        rightFoot=new SoccerPlayerExtremity();
        rightFoot->init("rightfoot", "characterscript.u4d");
        rightFoot->setBoneToFollow("foot.R");
        addChild(rightFoot);
        
        //add left foot as a child
        leftFoot=new SoccerPlayerExtremity();
        leftFoot->init("leftfoot", "characterscript.u4d");
        leftFoot->setBoneToFollow("foot.L");
        addChild(leftFoot);
        
        if (loadAnimationToModel(walkingAnimation, "walking", "walkinganimationscript.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(runningAnimation, "running", "runninganimationscript.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(forwardCarryAnimation, "forwardcarry", "forwardcarryanimationscript.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(sideCarryLeftAnimation, "sidecarryleft", "sidecarryleftanimationscript.u4d")) {
            
            
            
        }

        if (loadAnimationToModel(sideCarryRightAnimation, "sidecarryright", "sidecarryrightanimationscript.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(idleAnimation, "idle", "idleanimationscript.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(haltBallWithRightFootAnimation, "haltballwithrightfoot", "haltballwithrightfootanimationscript.u4d")) {
            
            haltBallWithRightFootAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(haltBallWithLeftFootAnimation, "haltballwithleftfoot", "haltballwithleftfootanimationscript.u4d")) {
            
            haltBallWithLeftFootAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(rightFootSidePassAnimation, "rightfootsidepass", "rightfootsidepassanimationscript.u4d")) {
            
            rightFootSidePassAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(leftFootSidePassAnimation, "leftfootsidepass", "leftfootsidepassanimationscript.u4d")) {
            
            leftFootSidePassAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(rightFootForwardKickAnimation, "rightfootforwardkick", "rightfootforwardkickanimationscript.u4d")) {
            
            rightFootForwardKickAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(leftFootForwardKickAnimation, "leftfootforwardkick", "leftfootforwardkickanimationscript.u4d")) {
            
            leftFootForwardKickAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(reverseBallWithRightFootAnimation, "reverseballwithrightfoot", "reverseballwithrightfootanimationscript.u4d")) {
            
            reverseBallWithRightFootAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(reverseBallWithLeftFootAnimation, "reverseballwithleftfoot", "reverseballwithleftfootanimationscript.u4d")) {
            
            reverseBallWithLeftFootAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        SoccerPlayerStateInterface *chaseBallState=SoccerPlayerChaseBallState::sharedInstance();
        SoccerPlayerStateInterface *idleState=SoccerPlayerIdleState::sharedInstance();
        SoccerPlayerGroundPassState *groundPassState=SoccerPlayerGroundPassState::sharedInstance();
        SoccerPlayerDribbleState *dribbleState=SoccerPlayerDribbleState::sharedInstance();
        
        //set initial state
        changeState(chaseBallState);
        
        //render information
        loadRenderingInformation();
        
        //translate the player
        translateBy(0.0, getModelDimensions().y/2.0+1.3, 0.0);
        
    }
    
}

void SoccerPlayer::setPlayerHeading(U4DEngine::U4DVector3n& uHeading){
    
    uHeading.x*=fieldLength;
    uHeading.z*=fieldWidth;
    
    //set view heading of player
    viewInDirection(uHeading);
    
}

U4DEngine::U4DVector3n SoccerPlayer::getPlayerHeading(){
    
    return getViewInDirection();
    
}

void SoccerPlayer::update(double dt){

    updatePlayerExtremity(rightFoot);
    updatePlayerExtremity(leftFoot);
    
    stateManager->update(dt);

}


void SoccerPlayer::updatePlayerExtremity(SoccerPlayerExtremity *uPlayerExtremity){
    
    if (getCurrentPlayingAnimation()!=NULL) {
        
        U4DEngine::U4DMatrix4n animationBlenderMatrix=getCurrentPlayingAnimation()->modelerAnimationTransform;
        
        U4DEngine::U4DDualQuaternion boneSpace=getBoneAnimationSpace(uPlayerExtremity->getBoneToFollow());
        
        U4DEngine::U4DMatrix4n boneMatrix=boneSpace.transformDualQuaternionToMatrix4n();
        
        boneMatrix=animationBlenderMatrix.inverse()*boneMatrix*animationBlenderMatrix;
        
        uPlayerExtremity->setLocalSpace(boneMatrix);
        
    }
    
}


void SoccerPlayer::changeState(SoccerPlayerStateInterface* uState){
    
    stateManager->safeChangeState(uState);
    
}

void SoccerPlayer::trackBall(){
    
    U4DEngine::U4DVector3n ballPosition=soccerBallEntity->getAbsolutePosition();
    
    U4DEngine::U4DVector3n playerPosition=getAbsolutePosition();
    
    U4DEngine::U4DVector3n distanceVector=ballPosition-playerPosition;
    
    U4DEngine::U4DVector3n directionToLook(distanceVector.x,playerPosition.y,distanceVector.z);
    
    setPlayerHeading(directionToLook);
    
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
    
    float distance=(ballPosition-playerPosition).magnitude()-ballRadius;
    
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

U4DEngine::U4DAnimation *SoccerPlayer::getRightFootSidePassAnimation(){
    return rightFootSidePassAnimation;
}

U4DEngine::U4DAnimation *SoccerPlayer::getLeftFootSidePassAnimation(){
    return leftFootSidePassAnimation;
}

U4DEngine::U4DAnimation *SoccerPlayer::getForwardCarryAnimation(){
    
    return forwardCarryAnimation;
}

U4DEngine::U4DAnimation *SoccerPlayer::getIdleAnimation(){
    
    return idleAnimation;
    
}

U4DEngine::U4DAnimation *SoccerPlayer::getHaltBallWithRightFootAnimation(){
    
    return haltBallWithRightFootAnimation;
}

U4DEngine::U4DAnimation *SoccerPlayer::getHaltBallWithLeftFootAnimation(){
    
    return haltBallWithLeftFootAnimation;
}

U4DEngine::U4DAnimation *SoccerPlayer::getRightFootForwardKickAnimation(){
    
    return rightFootForwardKickAnimation;

}

U4DEngine::U4DAnimation *SoccerPlayer::getLeftFootForwardKickAnimation(){
   
    return leftFootForwardKickAnimation;

}

U4DEngine::U4DAnimation *SoccerPlayer::getReverseBallWithLeftFootAnimation(){
    
    return reverseBallWithLeftFootAnimation;
    
}

U4DEngine::U4DAnimation *SoccerPlayer::getReverseBallWithRightFootAnimation(){
 
    return reverseBallWithRightFootAnimation;
    
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

void SoccerPlayer::kickBallToAir(float uVelocity, U4DEngine::U4DVector3n uDirection, double dt){
    
    soccerBallEntity->kickBallToAir(uVelocity, uDirection, dt);
}

void SoccerPlayer::setJoystickDirection(U4DEngine::U4DVector3n uJoystickDirection){
    
    joystickDirection=uJoystickDirection;
}

U4DEngine::U4DVector3n SoccerPlayer::getJoystickDirection(){
    
    return joystickDirection;

}


SoccerPlayerExtremity *SoccerPlayer::getRightFoot(){
    
    return rightFoot;
}

SoccerPlayerExtremity *SoccerPlayer::getLeftFoot(){
    
    return leftFoot;
    
}

bool SoccerPlayer::getRightFootCollidedWithBall(){
    
    return rightFoot->getModelHasCollided();
}

bool SoccerPlayer::getLeftFootCollidedWithBall(){
    
    return leftFoot->getModelHasCollided();
}

bool SoccerPlayer::getActiveExtremityCollidedWithBall(){
    
    return activeExtremity->getModelHasCollided();
}

void SoccerPlayer::setFlagToPassBall(bool uValue){
    
    flagToPassBall=uValue;
    
}

bool SoccerPlayer::getFlagToPassBall(){
    
    return flagToPassBall;
    
}

bool SoccerPlayer::isRightFootCloserToBall(){
    
    //check which foot is closer to the ball
    
    return (rightFoot->distanceToBall(getBallEntity())<=leftFoot->distanceToBall(getBallEntity()));
    
}

bool SoccerPlayer::isBallOnRightSidePlane(){
    
    U4DEngine::U4DVector3n playerHeading=getPlayerHeading();
    
    playerHeading.normalize();
    
    U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
    
    U4DEngine::U4DVector3n directionVector=playerHeading.cross(upVector);
    
    directionVector.normalize();
    
    U4DEngine::U4DVector3n ballPosition=soccerBallEntity->getAbsolutePosition();
    
    U4DEngine::U4DVector3n playerPosition=getAbsolutePosition();
    
    playerPosition.y=ballPosition.y;
    
    U4DEngine::U4DVector3n ballPlayerPosition=ballPosition-playerPosition;
    
    ballPlayerPosition.normalize();
    
    if (directionVector.dot(ballPlayerPosition)>=0.0) {
        return true;
    }else{
        return false;
    }
    
}

void SoccerPlayer::setActiveExtremity(SoccerPlayerExtremity *uActiveExtremity){
    activeExtremity=uActiveExtremity;
}

SoccerPlayerExtremity *SoccerPlayer::getActiveExtremity(){
    return activeExtremity;
}

void SoccerPlayer::decelerateBall(float uScale, double dt){
    
    soccerBallEntity->decelerate(uScale, dt);
    
}

void SoccerPlayer::setDirectionReversal(bool uValue){
    
    directionReversal=uValue;
}

bool SoccerPlayer::getDirectionReversal(){
    
    return directionReversal;
}

void SoccerPlayer::decelerate(float uScale, double dt){
    
    U4DEngine::U4DVector3n playerVelocity=getVelocity();
    
    playerVelocity*=uScale;
    
    U4DEngine::U4DVector3n forceToPlayer=(playerVelocity*getMass())/dt;
    
    addForce(forceToPlayer);
    
    //zero out the velocities
    U4DEngine::U4DVector3n initialVelocity(0.0,0.0,0.0);
    
    setVelocity(initialVelocity);
    setAngularVelocity(initialVelocity);
    
}



