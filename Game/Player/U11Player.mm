//
//  U11Player.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/30/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11Player.h"
#include "UserCommonProtocols.h"
#include "U11PlayerStateManager.h"
#include "U11PlayerStateInterface.h"
#include "U11PlayerIdleState.h"
#include "U11PlayerChaseBallState.h"
#include "U11PlayerDribbleState.h"
#include "U11PlayerGroundPassState.h"
#include "U11PlayerReceiveBallState.h"
#include "U11Ball.h"
#include "U11PlayerExtremity.h"
#include "U4DTrigonometry.h"
#include "U4DBoneData.h"

U11Player::U11Player():buttonAPressed(false),buttonBPressed(false),joystickActive(false),flagToPassBall(false){
    
    stateManager=new U11PlayerStateManager(this);
    
}
U11Player::~U11Player(){
    
    delete stateManager;
    
}

void U11Player::init(const char* uName, const char* uBlenderFile){
    
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
        //setCollisionFilterCategory(kU11Player);
        //setCollisionFilterMask(kU11Ball);
        
        //set player collision with ball filter to occur
        setCollisionFilterGroupIndex(kZeroGroupIndex);
        
        U4DEngine::U4DVector3n viewDirectionVector(0,0,1);
        
        setEntityForwardVector(viewDirectionVector);
        
        //add right foot as a child
        rightFoot=new U11PlayerExtremity();
        rightFoot->init("rightfoot", "characterscript.u4d");
        rightFoot->setBoneToFollow("foot.R");
        addChild(rightFoot);
        
        //add left foot as a child
        leftFoot=new U11PlayerExtremity();
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
        
        U11PlayerStateInterface *chaseBallState=U11PlayerChaseBallState::sharedInstance();
        U11PlayerStateInterface *idleState=U11PlayerIdleState::sharedInstance();
        U11PlayerGroundPassState *groundPassState=U11PlayerGroundPassState::sharedInstance();
        U11PlayerDribbleState *dribbleState=U11PlayerDribbleState::sharedInstance();
        
        //set initial state
        changeState(U11PlayerIdleState::sharedInstance());
        
        //render information
        loadRenderingInformation();
        
        //translate the player
        translateBy(-20.0, getModelDimensions().y/2.0+1.3, 30.0);
        
    }
    
}

void U11Player::setPlayerHeading(U4DEngine::U4DVector3n& uHeading){
    
    uHeading.x*=fieldLength;
    uHeading.z*=fieldWidth;
    
    //set view heading of player
    viewInDirection(uHeading);
    
}

U4DEngine::U4DVector3n U11Player::getPlayerHeading(){
    
    return getViewInDirection();
    
}

void U11Player::update(double dt){

    updatePlayerExtremity(rightFoot);
    updatePlayerExtremity(leftFoot);
    
    stateManager->update(dt);

}


void U11Player::updatePlayerExtremity(U11PlayerExtremity *uPlayerExtremity){
    
    if (getCurrentPlayingAnimation()!=NULL) {
        
        U4DEngine::U4DMatrix4n animationBlenderMatrix=getCurrentPlayingAnimation()->modelerAnimationTransform;
        
        U4DEngine::U4DDualQuaternion boneSpace=getBoneAnimationSpace(uPlayerExtremity->getBoneToFollow());
        
        U4DEngine::U4DMatrix4n boneMatrix=boneSpace.transformDualQuaternionToMatrix4n();
        
        boneMatrix=animationBlenderMatrix.inverse()*boneMatrix*animationBlenderMatrix;
        
        uPlayerExtremity->setLocalSpace(boneMatrix);
        
    }
    
}


void U11Player::changeState(U11PlayerStateInterface* uState){
    
    stateManager->safeChangeState(uState);
    
}

void U11Player::seekBall(){
    
    U4DEngine::U4DVector3n ballPosition=soccerBallEntity->getAbsolutePosition();
    
    U4DEngine::U4DVector3n playerPosition=getAbsolutePosition();
    
    U4DEngine::U4DVector3n distanceVector=ballPosition-playerPosition;
    
    U4DEngine::U4DVector3n directionToLook(distanceVector.x,playerPosition.y,distanceVector.z);
    
    setPlayerHeading(directionToLook);
    
}

void U11Player::interseptBall(){
    
    U4DEngine::U4DVector3n ballPosition=soccerBallEntity->getAbsolutePosition();
    
    U4DEngine::U4DVector3n playerPosition=getAbsolutePosition();
    
    U4DEngine::U4DVector3n distanceVector=ballPosition-playerPosition;
    
    float distanceMagnitude=distanceVector.magnitude();
    
    float ballVelocityMagnitude=soccerBallEntity->getVelocity().magnitude();
    
    float playerVelocityMagnitude=getVelocity().magnitude();
    
    if (ballVelocityMagnitude!=0 || playerVelocityMagnitude!=0) {
        
        float t=distanceMagnitude/(ballVelocityMagnitude+playerVelocityMagnitude);
        
        U4DEngine::U4DVector3n interseptPosition=ballPosition+soccerBallEntity->getVelocity()*t;
        
        U4DEngine::U4DVector3n directionToLook(interseptPosition.x,playerPosition.y,interseptPosition.z);
        
        directionToLook.x/=fieldLength;
        directionToLook.z/=fieldWidth;
        
        setPlayerHeading(directionToLook);
        
    }
    
}

void U11Player::setBallEntity(U11Ball *uU11Ball){
    
    soccerBallEntity=uU11Ball;
}

U11Ball *U11Player::getBallEntity(){
    
    return soccerBallEntity;
}

void U11Player::applyForceToPlayer(float uVelocity, double dt){
    
    U4DEngine::U4DVector3n heading=getViewInDirection();
    
    heading.normalize();
    
    U4DEngine::U4DVector3n forceToPlayer=(heading*uVelocity*getMass())/dt;
    
    addForce(forceToPlayer);
    
    U4DEngine::U4DVector3n initialVelocity(0.0,0.0,0.0);
    
    setVelocity(initialVelocity);
    
}

float U11Player::distanceToBall(){
    
    U4DEngine::U4DVector3n ballPosition=soccerBallEntity->getAbsolutePosition();
    
    U4DEngine::U4DVector3n playerPosition=getAbsolutePosition();
    
    //set the height position equal to the ball y position
    playerPosition.y=ballPosition.y;
    
    float ballRadius=soccerBallEntity->getBallRadius();
    
    float distance=(ballPosition-playerPosition).magnitude()-ballRadius;
    
    return distance;
}

bool U11Player::hasReachedTheBall(){
    
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

U4DEngine::U4DAnimation *U11Player::getRunningAnimation(){
    return runningAnimation;
}

U4DEngine::U4DAnimation *U11Player::getRightFootSidePassAnimation(){
    return rightFootSidePassAnimation;
}

U4DEngine::U4DAnimation *U11Player::getLeftFootSidePassAnimation(){
    return leftFootSidePassAnimation;
}

U4DEngine::U4DAnimation *U11Player::getForwardCarryAnimation(){
    
    return forwardCarryAnimation;
}

U4DEngine::U4DAnimation *U11Player::getIdleAnimation(){
    
    return idleAnimation;
    
}

U4DEngine::U4DAnimation *U11Player::getHaltBallWithRightFootAnimation(){
    
    return haltBallWithRightFootAnimation;
}

U4DEngine::U4DAnimation *U11Player::getHaltBallWithLeftFootAnimation(){
    
    return haltBallWithLeftFootAnimation;
}

U4DEngine::U4DAnimation *U11Player::getRightFootForwardKickAnimation(){
    
    return rightFootForwardKickAnimation;

}

U4DEngine::U4DAnimation *U11Player::getLeftFootForwardKickAnimation(){
   
    return leftFootForwardKickAnimation;

}

U4DEngine::U4DAnimation *U11Player::getReverseBallWithLeftFootAnimation(){
    
    return reverseBallWithLeftFootAnimation;
    
}

U4DEngine::U4DAnimation *U11Player::getReverseBallWithRightFootAnimation(){
 
    return reverseBallWithRightFootAnimation;
    
}

void U11Player::receiveTouchUpdate(bool uButtonAPressed, bool uButtonBPressed, bool uJoystickActive){
    
    buttonAPressed=uButtonAPressed;
    buttonBPressed=uButtonBPressed;
    joystickActive=uJoystickActive;
    
}

void U11Player::setButtonAPressed(bool uValue){
    
    buttonAPressed=uValue;
}

void U11Player::setButtonBPressed(bool uValue){
    
    buttonBPressed=uValue;
}

bool U11Player::getButtonAPressed(){
 
    return buttonAPressed;
}

bool U11Player::getButtonBPressed(){
    
    return buttonBPressed;
}

void U11Player::setJoystickActive(bool uValue){
    
    joystickActive=uValue;
}

bool U11Player::getJoystickActive(){
    
    return joystickActive;
}

void U11Player::removeKineticForces(){
    
    clearForce();
    clearMoment();
    
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    setVelocity(zero);
    setAngularVelocity(zero);
}

void U11Player::kickBallToGround(float uVelocity, U4DEngine::U4DVector3n uDirection, double dt){
    
    soccerBallEntity->kickBallToGround(uVelocity, uDirection, dt);
}

void U11Player::kickBallToAir(float uVelocity, U4DEngine::U4DVector3n uDirection, double dt){
    
    soccerBallEntity->kickBallToAir(uVelocity, uDirection, dt);
}

void U11Player::setJoystickDirection(U4DEngine::U4DVector3n uJoystickDirection){
    
    joystickDirection=uJoystickDirection;
}

U4DEngine::U4DVector3n U11Player::getJoystickDirection(){
    
    return joystickDirection;

}


U11PlayerExtremity *U11Player::getRightFoot(){
    
    return rightFoot;
}

U11PlayerExtremity *U11Player::getLeftFoot(){
    
    return leftFoot;
    
}

bool U11Player::getRightFootCollidedWithBall(){
    
    return rightFoot->getModelHasCollided();
}

bool U11Player::getLeftFootCollidedWithBall(){
    
    return leftFoot->getModelHasCollided();
}

bool U11Player::getActiveExtremityCollidedWithBall(){
    
    return activeExtremity->getModelHasCollided();
}

void U11Player::setFlagToPassBall(bool uValue){
    
    flagToPassBall=uValue;
    
}

bool U11Player::getFlagToPassBall(){
    
    return flagToPassBall;
    
}

bool U11Player::isRightFootCloserToBall(){
    
    //check which foot is closer to the ball
    
    return (rightFoot->distanceToBall(getBallEntity())<=leftFoot->distanceToBall(getBallEntity()));
    
}

bool U11Player::isBallOnRightSidePlane(){
    
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

void U11Player::setActiveExtremity(U11PlayerExtremity *uActiveExtremity){
    activeExtremity=uActiveExtremity;
}

U11PlayerExtremity *U11Player::getActiveExtremity(){
    return activeExtremity;
}

void U11Player::decelerateBall(float uScale, double dt){
    
    soccerBallEntity->decelerate(uScale, dt);
    
}

void U11Player::setDirectionReversal(bool uValue){
    
    directionReversal=uValue;
}

bool U11Player::getDirectionReversal(){
    
    return directionReversal;
}

void U11Player::decelerate(float uScale, double dt){
    
    U4DEngine::U4DVector3n playerVelocity=getVelocity();
    
    playerVelocity*=uScale;
    
    U4DEngine::U4DVector3n forceToPlayer=(playerVelocity*getMass())/dt;
    
    addForce(forceToPlayer);
    
    //zero out the velocities
    U4DEngine::U4DVector3n initialVelocity(0.0,0.0,0.0);
    
    setVelocity(initialVelocity);
    setAngularVelocity(initialVelocity);
    
}



