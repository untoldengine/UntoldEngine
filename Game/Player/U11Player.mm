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
#include "U11Team.h"

U11Player::U11Player():joystickActive(false){
    
    stateManager=new U11PlayerStateManager(this);
    
}
U11Player::~U11Player(){
    
    delete stateManager;
    
}

void U11Player::init(const char* uModelName, const char* uBlenderFile){
    
    if (loadModel(uModelName, uBlenderFile)) {
        
        walkingAnimation=new U4DEngine::U4DAnimation(this);
        runningAnimation=new U4DEngine::U4DAnimation(this);
        
        forwardCarryAnimation=new U4DEngine::U4DAnimation(this);
        sideCarryRightAnimation=new U4DEngine::U4DAnimation(this);
        sideCarryLeftAnimation=new U4DEngine::U4DAnimation(this);
        idleAnimation=new U4DEngine::U4DAnimation(this);
        
        forwardHaltBallWithRightFootAnimation=new U4DEngine::U4DAnimation(this);
        forwardHaltBallWithLeftFootAnimation=new U4DEngine::U4DAnimation(this);
        backHaltBallWithRightFootAnimation=new U4DEngine::U4DAnimation(this);
        backHaltBallWithLeftFootAnimation=new U4DEngine::U4DAnimation(this);
        sideHaltBallWithRightFootAnimation=new U4DEngine::U4DAnimation(this);
        sideHaltBallWithLeftFootAnimation=new U4DEngine::U4DAnimation(this);
        
        rightFootSidePassAnimation=new U4DEngine::U4DAnimation(this);
        leftFootSidePassAnimation=new U4DEngine::U4DAnimation(this);
        rightFootForwardKickAnimation=new U4DEngine::U4DAnimation(this);
        leftFootForwardKickAnimation=new U4DEngine::U4DAnimation(this);
        reverseBallWithRightFootAnimation=new U4DEngine::U4DAnimation(this);
        reverseBallWithLeftFootAnimation=new U4DEngine::U4DAnimation(this);
        
        reverseRunningAnimation=new U4DEngine::U4DAnimation(this);
        lateralLeftRunAnimation=new U4DEngine::U4DAnimation(this);
        lateralRightRunAnimation=new U4DEngine::U4DAnimation(this);
        
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
        
        if (loadAnimationToModel(walkingAnimation, "walking", "walkinganimation.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(runningAnimation, "running", "runninganimation.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(forwardCarryAnimation, "forwardcarry", "forwardcarryanimation.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(sideCarryLeftAnimation, "sidecarryleft", "sidecarryleftanimation.u4d")) {
            
            
            
        }

        if (loadAnimationToModel(sideCarryRightAnimation, "sidecarryright", "sidecarryrightanimation.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(idleAnimation, "idle", "idleanimation.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(forwardHaltBallWithRightFootAnimation, "forwardhaltballwithrightfoot", "forwardhaltballwithrightfootanimation.u4d")) {
            
            forwardHaltBallWithRightFootAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(forwardHaltBallWithLeftFootAnimation, "forwardhaltballwithleftfoot", "forwardhaltballwithleftfootanimation.u4d")) {
            
            forwardHaltBallWithLeftFootAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(backHaltBallWithRightFootAnimation, "backhaltballwithrightfoot", "backhaltballwithrightfootanimation.u4d")) {
            
            backHaltBallWithRightFootAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(backHaltBallWithLeftFootAnimation, "backhaltballwithleftfoot", "backhaltballwithleftfootanimation.u4d")) {
            
            backHaltBallWithLeftFootAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(sideHaltBallWithRightFootAnimation, "sidehaltballwithrightfoot", "sidehaltballwithrightfootanimation.u4d")) {
            
            sideHaltBallWithRightFootAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(sideHaltBallWithLeftFootAnimation, "sidehaltballwithleftfoot", "sidehaltballwithleftfootanimation.u4d")) {
            
            sideHaltBallWithLeftFootAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(rightFootSidePassAnimation, "rightfootsidepass", "rightfootsidepassanimation.u4d")) {
            
            rightFootSidePassAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(leftFootSidePassAnimation, "leftfootsidepass", "leftfootsidepassanimation.u4d")) {
            
            leftFootSidePassAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(rightFootForwardKickAnimation, "rightfootforwardkick", "rightfootforwardkickanimation.u4d")) {
            
            rightFootForwardKickAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(leftFootForwardKickAnimation, "leftfootforwardkick", "leftfootforwardkickanimation.u4d")) {
            
            leftFootForwardKickAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(reverseBallWithRightFootAnimation, "reverseballwithrightfoot", "reverseballwithrightfootanimation.u4d")) {
            
            reverseBallWithRightFootAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(reverseBallWithLeftFootAnimation, "reverseballwithleftfoot", "reverseballwithleftfootanimation.u4d")) {
            
            reverseBallWithLeftFootAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(reverseRunningAnimation, "reverserunning", "reverserunninganimation.u4d")) {
            
            reverseRunningAnimation->setIsAllowedToBeInterrupted(true);
            
        }
        
        if (loadAnimationToModel(lateralRightRunAnimation, "lateralrightrun", "lateralrightrunanimation.u4d")) {
            
            lateralRightRunAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(lateralLeftRunAnimation, "lateralleftrun", "lateralleftrunanimation.u4d")) {
            
            lateralLeftRunAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        
        //set initial state
        changeState(U11PlayerIdleState::sharedInstance());
        
        //render information
        loadRenderingInformation();
        
    }
    
}

void U11Player::subscribeTeam(U11Team *uTeam){
 
    team=uTeam;
    team->subscribe(this);
}

U11Team *U11Player::getTeam(){
    
    return team;
    
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

U11Ball *U11Player::getSoccerBall(){
    
    return team->getSoccerBall();
}

void U11Player::seekBall(){
    
    U4DEngine::U4DVector3n ballPosition=getSoccerBall()->getAbsolutePosition();
    
    U4DEngine::U4DVector3n playerPosition=getAbsolutePosition();
    
    U4DEngine::U4DVector3n distanceVector=ballPosition-playerPosition;
    
    U4DEngine::U4DVector3n directionToLook(distanceVector.x,playerPosition.y,distanceVector.z);
    
    setPlayerHeading(directionToLook);
    
}

void U11Player::interseptBall(){
    
    //determine the heading of the ball relative to the player
    U4DEngine::U4DVector3n ballHeading=getSoccerBall()->getVelocity();
    ballHeading.normalize();
    
    U4DEngine::U4DVector3n ballPosition=getSoccerBall()->getAbsolutePosition();
    
    U4DEngine::U4DVector3n playerPosition=getAbsolutePosition();
    
    U4DEngine::U4DVector3n relativePosition=ballPosition-playerPosition;
    relativePosition.normalize();
    
    U4DEngine::U4DVector3n playerHeading=getPlayerHeading();
    playerHeading.normalize();
    
    if (playerHeading.dot(relativePosition)>0.0 && (ballHeading.dot(playerHeading)<-0.95)) {
        
        seekBall();
        
    }else{
        
        float t=(ballPosition-playerPosition).magnitude()/maximumInterceptionSpeed;
        
        U4DEngine::U4DVector3n interseptPosition=ballPosition+getSoccerBall()->getVelocity()*t;
        
        U4DEngine::U4DVector3n directionToLook(interseptPosition.x,playerPosition.y,interseptPosition.z);
        
        directionToLook.x/=fieldLength;
        directionToLook.z/=fieldWidth;
        
        setPlayerHeading(directionToLook);

    }
        
}


void U11Player::applyForceToPlayer(float uVelocity, double dt){
    
    U4DEngine::U4DVector3n heading=getViewInDirection();
    
    heading.normalize();
    
    U4DEngine::U4DVector3n forceToPlayer=(heading*uVelocity*getMass())/dt;
    
    addForce(forceToPlayer);
    
    U4DEngine::U4DVector3n initialVelocity(0.0,0.0,0.0);
    
    setVelocity(initialVelocity);
    
}

void U11Player::applyForceToPlayerInDirection(float uVelocity, U4DEngine::U4DVector3n &uDirection, double dt){
    
    U4DEngine::U4DVector3n heading=uDirection;
    
    heading.normalize();
    
    U4DEngine::U4DVector3n forceToPlayer=(heading*uVelocity*getMass())/dt;
    
    addForce(forceToPlayer);
    
    U4DEngine::U4DVector3n initialVelocity(0.0,0.0,0.0);
    
    setVelocity(initialVelocity);
    
}

float U11Player::distanceToBall(){
    
    U4DEngine::U4DVector3n ballPosition=getSoccerBall()->getAbsolutePosition();
    
    U4DEngine::U4DVector3n playerPosition=getAbsolutePosition();
    
    //set the height position equal to the ball y position
    playerPosition.y=ballPosition.y;
    
    float ballRadius=getSoccerBall()->getBallRadius();
    
    float distance=(ballPosition-playerPosition).magnitude()-ballRadius;
    
    return distance;
}

bool U11Player::hasReachedTheBall(){
    
    U4DEngine::U4DVector3n ballPosition=team->getSoccerBall()->getAbsolutePosition();
    
    U4DEngine::U4DVector3n playerPosition=getAbsolutePosition();
   
    //set the height position equal to the ball y position
    playerPosition.y=ballPosition.y;
    
    float ballRadius=team->getSoccerBall()->getBallRadius();
    
    float distanceToBall=(ballPosition-playerPosition).magnitude();
    
    if (distanceToBall<=(ballRadius+2.5)) {
        
        return true;
    }
    
    return false;
    
}

bool U11Player::hasReachedSupportPosition(U4DEngine::U4DVector3n &uSupportPosition){
    
    U4DEngine::U4DVector3n playerPosition=getAbsolutePosition();
    
    //set the height position equal to the y position
    playerPosition.y=uSupportPosition.y;
    
    float distanceToOpenPosition=(uSupportPosition-playerPosition).magnitude();
    
    if (distanceToOpenPosition<=2.5) {
        
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

U4DEngine::U4DAnimation *U11Player::getForwardHaltBallWithRightFootAnimation(){
    
    return forwardHaltBallWithRightFootAnimation;
}

U4DEngine::U4DAnimation *U11Player::getForwardHaltBallWithLeftFootAnimation(){
    
    return forwardHaltBallWithLeftFootAnimation;
}

U4DEngine::U4DAnimation *U11Player::getBackHaltBallWithRightFootAnimation(){
    
    return backHaltBallWithRightFootAnimation;
}

U4DEngine::U4DAnimation *U11Player::getBackHaltBallWithLeftFootAnimation(){
    
    return backHaltBallWithLeftFootAnimation;
}

U4DEngine::U4DAnimation *U11Player::getSideHaltBallWithRightFootAnimation(){
    
    return sideHaltBallWithRightFootAnimation;
}

U4DEngine::U4DAnimation *U11Player::getSideHaltBallWithLeftFootAnimation(){
    
    return sideHaltBallWithLeftFootAnimation;
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

U4DEngine::U4DAnimation *U11Player::getReverseRunningAnimation(){
    
    return reverseRunningAnimation;
}

U4DEngine::U4DAnimation *U11Player::getLateralRightRunAnimation(){
 
    return lateralRightRunAnimation;
}

U4DEngine::U4DAnimation *U11Player::getLateralLeftRunAnimation(){
    
    return lateralLeftRunAnimation;
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
    
    getSoccerBall()->kickBallToGround(uVelocity, uDirection, dt);
}

void U11Player::kickBallToAir(float uVelocity, U4DEngine::U4DVector3n uDirection, double dt){
    
    getSoccerBall()->kickBallToAir(uVelocity, uDirection, dt);
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


bool U11Player::isRightFootCloserToBall(){
    
    //check which foot is closer to the ball
    
    return (rightFoot->distanceToBall(getSoccerBall())<=leftFoot->distanceToBall(getSoccerBall()));
    
}

bool U11Player::isBallOnRightSidePlane(){
    
    U4DEngine::U4DVector3n playerHeading=getPlayerHeading();
    
    playerHeading.normalize();
    
    U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
    
    U4DEngine::U4DVector3n directionVector=playerHeading.cross(upVector);
    
    directionVector.normalize();
    
    U4DEngine::U4DVector3n ballPosition=getSoccerBall()->getAbsolutePosition();
    
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

bool U11Player::isBallComingFromRightSidePlane(){
    
    U4DEngine::U4DVector3n playerHeading=getPlayerHeading();
    
    playerHeading.normalize();
    
    U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
    
    U4DEngine::U4DVector3n directionVector=playerHeading.cross(upVector);
    
    directionVector.normalize();
    
    U4DEngine::U4DVector3n ballHeading=getSoccerBall()->getVelocity();
    
    ballHeading.normalize();
    
    if(ballHeading.dot(directionVector)<=0.0){
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
    
    getSoccerBall()->decelerate(uScale, dt);
    
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

bool U11Player::handleMessage(Message &uMsg){
    
    return stateManager->handleMessage(uMsg);
    
}

void U11Player::removeAllVelocities(){
    
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    
    setVelocity(zero);
    setAngularVelocity(zero);
}

void U11Player::setSupportPosition(U4DEngine::U4DVector3n &uSupportPosition){
    
    supportPosition=uSupportPosition;
    
}

U4DEngine::U4DVector3n &U11Player::getSupportPosition(){
    
    return supportPosition;
    
}

U11PlayerStateInterface *U11Player::getCurrentState(){
    
    return stateManager->getCurrentState();
}

