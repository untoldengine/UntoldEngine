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
#include "U11FormationEntity.h"
#include "U11PlayerSpace.h"

U11Player::U11Player():joystickActive(false),missedTheBall(false),ballKickSpeed(0),threateningPlayer(nullptr),processedForTriangleNode(false),rightHanded(1.0){
    
    stateManager=new U11PlayerStateManager(this);
    
    
}
U11Player::~U11Player(){
    
    delete stateManager;
    
}

void U11Player::init(const char* uModelName, const char* uBlenderFile){
    
    if (loadModel(uModelName, uBlenderFile)) {
        
        //setEntityType(U4DEngine::MODELNOSHADOWS);
        walkingAnimation=new U4DEngine::U4DAnimation(this);
        runningAnimation=new U4DEngine::U4DAnimation(this);
        
        rightDribbleAnimation=new U4DEngine::U4DAnimation(this);
        leftDribbleAnimation=new U4DEngine::U4DAnimation(this);
        
        
        idleAnimation=new U4DEngine::U4DAnimation(this);
        
        rightSoleHaltAnimation=new U4DEngine::U4DAnimation(this);
        leftSoleHaltAnimation=new U4DEngine::U4DAnimation(this);
        rightInsideHaltAnimation=new U4DEngine::U4DAnimation(this);
        leftInsideHaltAnimation=new U4DEngine::U4DAnimation(this);
        rightSideHaltAnimation=new U4DEngine::U4DAnimation(this);
        leftSideHaltAnimation=new U4DEngine::U4DAnimation(this);
        
        rightPassAnimation=new U4DEngine::U4DAnimation(this);
        leftPassAnimation=new U4DEngine::U4DAnimation(this);
        
        rightShotAnimation=new U4DEngine::U4DAnimation(this);
        leftShotAnimation=new U4DEngine::U4DAnimation(this);
        
        
        leftReverseKickAnimation=new U4DEngine::U4DAnimation(this);
        rightReverseKickAnimation=new U4DEngine::U4DAnimation(this);
        
        backPeddalAnimation=new U4DEngine::U4DAnimation(this);
        lateralLeftRunAnimation=new U4DEngine::U4DAnimation(this);
        lateralRightRunAnimation=new U4DEngine::U4DAnimation(this);
        
        markingAnimation=new U4DEngine::U4DAnimation(this);
        stealingAnimation=new U4DEngine::U4DAnimation(this);
        
        //set collision info
        initMass(80.0);
        initAsPlatform(true);
        initCoefficientOfRestitution(0.9);
        //enableCollisionBehavior();
        enableKineticsBehavior();
        
        
        //set gravity to zero
        U4DEngine::U4DVector3n zeroGravity(0.0,0.0,0.0);
        setGravity(zeroGravity);
        
        setEnableShadow(true);
        //set collision filters
//        setCollisionFilterCategory(kU11Player);
//        setCollisionFilterMask(kU11Ball);
//        
//        //set player collision with ball filter not to occur
//        setCollisionFilterGroupIndex(kNegativeGroupIndex);
        
        U4DEngine::U4DVector3n viewDirectionVector(0,0,-1);
        
        setEntityForwardVector(viewDirectionVector);
        
        //add right foot as a child
        rightFoot=new U11PlayerExtremity();
        rightFoot->init("rightfoot", uBlenderFile);
        rightFoot->setBoneToFollow("foot.R");
        addChild(rightFoot);
        
        //add left foot as a child
        leftFoot=new U11PlayerExtremity();
        leftFoot->init("leftfoot", uBlenderFile);
        leftFoot->setBoneToFollow("foot.L");
        addChild(leftFoot);
        
        //add playerspace object
        playerSpace=new U11PlayerSpace();
        playerSpace->init("playerspace", uBlenderFile);
        addChild(playerSpace);
        
        if (loadAnimationToModel(walkingAnimation, "walking", "walkinganimation.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(runningAnimation, "running", "runninganimation.u4d")) {
            
            
            
        }
        
        
        if (loadAnimationToModel(rightDribbleAnimation, "rightdribble", "rightdribbleanimation.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(leftDribbleAnimation, "leftdribble", "leftdribbleanimation.u4d")) {
            
            
            
        }
        
        
        
        if (loadAnimationToModel(idleAnimation, "idle", "idleanimation.u4d")) {
            
            
            
        }
        
        if (loadAnimationToModel(rightSoleHaltAnimation, "rightsolehalt", "rightsolehaltanimation.u4d")) {
            
            rightSoleHaltAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(leftSoleHaltAnimation, "leftsolehalt", "leftsolehaltanimation.u4d")) {
            
            leftSoleHaltAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(rightInsideHaltAnimation, "rightinsidehalt", "rightinsidehaltanimation.u4d")) {
            
            rightInsideHaltAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(leftInsideHaltAnimation, "leftinsidehalt", "leftinsidehaltanimation.u4d")) {
            
            leftInsideHaltAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(rightSideHaltAnimation, "rightsidehalt", "rightsidehaltanimation.u4d")) {
            
            rightSideHaltAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(leftSideHaltAnimation, "leftsidehalt", "leftsidehaltanimation.u4d")) {
            
            leftSideHaltAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(rightPassAnimation, "rightpass", "rightpassanimation.u4d")) {
            
            rightPassAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(leftPassAnimation, "leftpass", "leftpassanimation.u4d")) {
            
            leftPassAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(rightShotAnimation, "rightshot", "rightshotanimation.u4d")) {
            
            rightShotAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(leftShotAnimation, "leftshot", "leftshotanimation.u4d")) {
            
            leftShotAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(leftReverseKickAnimation, "leftreversekick", "leftreversekickanimation.u4d")) {
            
            leftReverseKickAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(rightReverseKickAnimation, "rightreversekick", "rightreversekickanimation.u4d")) {
            
            rightReverseKickAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(backPeddalAnimation, "backpeddal", "backpeddalanimation.u4d")) {
            
            backPeddalAnimation->setIsAllowedToBeInterrupted(true);
            
        }
        
        if (loadAnimationToModel(lateralRightRunAnimation, "lateralrightrun", "lateralrightrunanimation.u4d")) {
            
            lateralRightRunAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(lateralLeftRunAnimation, "lateralleftrun", "lateralleftrunanimation.u4d")) {
            
            lateralLeftRunAnimation->setIsAllowedToBeInterrupted(false);
            
        }
        
        if (loadAnimationToModel(markingAnimation, "marking", "markinganimation.u4d")) {
            
            markingAnimation->setIsAllowedToBeInterrupted(true);
            
        }
        
        if (loadAnimationToModel(stealingAnimation, "stealing", "stealinganimation.u4d")) {
            
            stealingAnimation->setIsAllowedToBeInterrupted(true);
            
        }
        
        pauseExtremityCollision();
        
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

void U11Player::seekPosition(U4DEngine::U4DPoint3n &uPosition){
    
    U4DEngine::U4DVector3n playerPosition=getAbsolutePosition();
    
    U4DEngine::U4DVector3n distanceVector=uPosition.toVector()-playerPosition;
    
    U4DEngine::U4DVector3n directionToLook(distanceVector.x,playerPosition.y,distanceVector.z);
    
    setPlayerHeading(directionToLook);
    
}

void U11Player::seekBall(){
    
    if (distanceToBall()>0.1) {
        
        U4DEngine::U4DVector3n ballPosition=getSoccerBall()->getAbsolutePosition();
        
        U4DEngine::U4DVector3n playerPosition=getAbsolutePosition();
        
        U4DEngine::U4DVector3n distanceVector=ballPosition-playerPosition;
        
        
        
        U4DEngine::U4DVector3n playerHeading=getPlayerHeading();
        
        playerHeading.normalize();
        
        U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
        
        U4DEngine::U4DVector3n offsetVector=playerHeading.cross(upVector);
        
        offsetVector*=rightHanded*offsetHandedness;
        
        distanceVector+=offsetVector;
        
        
        
        U4DEngine::U4DVector3n directionToLook(distanceVector.x,playerPosition.y,distanceVector.z);
        
        setPlayerHeading(directionToLook);
        
    }
    
    
}

void U11Player::interseptBall(){
    
    if (distanceToBall()>0.1) {
        
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
            
            float t=(relativePosition).magnitude();
            
            U4DEngine::U4DVector3n interseptPosition=ballPosition+ballHeading*t;
            
            
            
            U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
            
            U4DEngine::U4DVector3n offsetVector=playerHeading.cross(upVector);
            
            offsetVector*=rightHanded*offsetHandedness;
            
            interseptPosition+=offsetVector;
            
            
            U4DEngine::U4DVector3n directionToLook(interseptPosition.x,playerPosition.y,interseptPosition.z);
            
            directionToLook.x/=fieldLength;
            directionToLook.z/=fieldWidth;
            
            setPlayerHeading(directionToLook);
            
        }
        
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
    
    if (distanceToBall<=(ballRadius+0.5)) {
        
        return true;
    }
    
    return false;
    
}

bool U11Player::hasReachedPosition(U4DEngine::U4DPoint3n &uPosition, float uWithinDistance){
    
    U4DEngine::U4DVector3n playerPosition=getAbsolutePosition();
    
    //set the height position equal to the y position
    playerPosition.y=uPosition.y;
    
    float distanceToOpenPosition=(uPosition.toVector()-playerPosition).magnitude();
    
    if (distanceToOpenPosition<=uWithinDistance) {
        
        return true;
    }
    
    return false;
    
}

U4DEngine::U4DAnimation *U11Player::getRunningAnimation(){
    return runningAnimation;
}

U4DEngine::U4DAnimation *U11Player::getRightPassAnimation(){
    return rightPassAnimation;
}

U4DEngine::U4DAnimation *U11Player::getLeftPassAnimation(){
    return leftPassAnimation;
}

U4DEngine::U4DAnimation *U11Player::getRightDribbleAnimation(){
    
    return rightDribbleAnimation;
}

U4DEngine::U4DAnimation *U11Player::getLeftDribbleAnimation(){
    
    return leftDribbleAnimation;
}

U4DEngine::U4DAnimation *U11Player::getIdleAnimation(){
    
    return idleAnimation;
    
}

U4DEngine::U4DAnimation *U11Player::getRightSoleHaltAnimation(){
    
    return rightSoleHaltAnimation;
}

U4DEngine::U4DAnimation *U11Player::getRightCarryAnimation(){
    
}

U4DEngine::U4DAnimation *U11Player::getLeftCarryAnimation(){
    
}

U4DEngine::U4DAnimation *U11Player::getLeftSoleHaltAnimation(){
    
    return leftSoleHaltAnimation;
}

U4DEngine::U4DAnimation *U11Player::getRightInsideHaltAnimation(){
    
    return rightInsideHaltAnimation;
}

U4DEngine::U4DAnimation *U11Player::getLeftInsideHaltAnimation(){
    
    return leftInsideHaltAnimation;
}

U4DEngine::U4DAnimation *U11Player::getRightSideHaltAnimation(){
    
    return rightSideHaltAnimation;
}

U4DEngine::U4DAnimation *U11Player::getLeftSideHaltAnimation(){
    
    return leftSideHaltAnimation;
}

U4DEngine::U4DAnimation *U11Player::getRightShotAnimation(){
    
    return rightShotAnimation;

}

U4DEngine::U4DAnimation *U11Player::getLeftShotAnimation(){
   
    return leftShotAnimation;

}

U4DEngine::U4DAnimation *U11Player::getLeftReverseKickAnimation(){
    
    return leftReverseKickAnimation;
    
}

U4DEngine::U4DAnimation *U11Player::getRightReverseKickAnimation(){
 
    return rightReverseKickAnimation;
    
}

U4DEngine::U4DAnimation *U11Player::getBackPeddalAnimation(){
    
    return backPeddalAnimation;
}

U4DEngine::U4DAnimation *U11Player::getLateralRightRunAnimation(){
 
    return lateralRightRunAnimation;
}

U4DEngine::U4DAnimation *U11Player::getLateralLeftRunAnimation(){
    
    return lateralLeftRunAnimation;
}

U4DEngine::U4DAnimation *U11Player::getMarkingAnimation(){
    
    return markingAnimation;
}

U4DEngine::U4DAnimation *U11Player::getStealingAnimation(){
    
    return stealingAnimation;
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
    
    if (directionVector.dot(ballPlayerPosition)>0.0) {
        return false;
    }else{
        return true;
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

void U11Player::setSupportPosition(U4DEngine::U4DPoint3n &uSupportPosition){
    
    supportPosition=uSupportPosition;
    
}

U4DEngine::U4DPoint3n &U11Player::getSupportPosition(){
    
    return supportPosition;
    
}

void U11Player::setDefendingPosition(U4DEngine::U4DPoint3n &uDefendingPosition){
    
    defendingPosition=uDefendingPosition;
}

U4DEngine::U4DPoint3n &U11Player::getDefendingPosition(){
    
    return defendingPosition;
}

U11PlayerStateInterface *U11Player::getCurrentState(){
    
    return stateManager->getCurrentState();
}

U4DEngine::U4DAABB U11Player::getUpdatedPlayerSpaceBox(){
    
    return playerSpace->getUpdatedPlayerSpaceBox();
    
}

bool U11Player::isHeadingWithinRange(){
    
    U4DEngine::U4DVector3n joystickDirection=getJoystickDirection();
       
    if (getPlayerHeading().angle(joystickDirection)<90.0) {
        
        return true;
        
    }else{
        
        return false;
    }
}

void U11Player::setMissedTheBall(bool uValue){
    
    missedTheBall=uValue;
    
}

bool U11Player::getMissedTheBall(){
    
    return missedTheBall;
}

void U11Player::setFormationEntity(U11FormationEntity *uFormationEntity){
    
    formationEntity=uFormationEntity;
    
}

U11FormationEntity *U11Player::getFormationEntity(){
    
    return formationEntity;
}

void U11Player::setFormationPosition(U4DEngine::U4DPoint3n &uFormationPosition){
 
    formationPosition=uFormationPosition;
    
}

U4DEngine::U4DPoint3n &U11Player::getFormationPosition(){
    
    return formationPosition;
    
}

void U11Player::pauseExtremityCollision(){
    
    rightFoot->pauseCollisionBehavior();
    leftFoot->pauseCollisionBehavior();
    
}

void U11Player::resumeExtremityCollision(){
    
    rightFoot->resumeCollisionBehavior();
    leftFoot->resumeCollisionBehavior();
}

void U11Player::setBallKickSpeed(float uBallKickSpeed){
    
    ballKickSpeed=uBallKickSpeed;
}

float U11Player::getBallKickSpeed(){
    return ballKickSpeed;
}

void U11Player::setBallKickDirection(U4DEngine::U4DVector3n &uDirection){
    
    ballKickDirection=uDirection;
}

U4DEngine::U4DVector3n U11Player::getBallKickDirection(){
    
    return ballKickDirection;
    
}

void U11Player::setThreateningPlayer(U11Player* uThreateningPlayer){
    
    threateningPlayer=uThreateningPlayer;
}

U11Player* U11Player::getThreateningPlayer(){
    
    return threateningPlayer;
}

U4DEngine::U4DVector3n U11Player::getCurrentPosition(){
    
    U4DEngine::U4DVector3n position=getAbsolutePosition();
    
    position.y=0.0;
    
    return position;
}

void U11Player::setProcessedForTriangleNode(bool uValue){
    
    processedForTriangleNode=uValue;
    
}

bool U11Player::getProcessedForTriangleNode(){
    
    return processedForTriangleNode;
}

void U11Player::computePlayerDribblingSpeed(){
    
    float t=distanceToBall();
    
    t=t/ballControlMaximumDistance;
    
    if (t>1.0) {
        t=1.0;
    }
    
    playerDribblingSpeed=minDribblingSpeed+minDribblingSpeed*t;
    
}

float U11Player::getPlayerDribblingSpeed(){
    
    return playerDribblingSpeed;
}



