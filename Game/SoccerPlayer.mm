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
#include "SoccerPlayerFeet.h"
#include "U4DTrigonometry.h"
#include "U4DBoneData.h"

SoccerPlayer::SoccerPlayer():buttonAPressed(false),buttonBPressed(false),joystickActive(false),leftRightFootOffset(1.0),footSwingAngle(90.0),flagToPassBall(false){
    
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
        SoccerPlayerGroundPassState *groundPassState=SoccerPlayerGroundPassState::sharedInstance();
        
        //set initial state
        changeState(chaseBallState);
        
        //render information
        loadRenderingInformation();
        
        //translate the player
        translateBy(0.0, getModelDimensions().y/2.0+1.3, 0.0);
        
        //add right foot as a child
        rightFoot=new SoccerPlayerFeet();
        rightFoot->init("rightfoot", "characterscript.u4d");
        
        addChild(rightFoot);
        
        
        
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
    
    updateBoneSpace("foot.R", rightFoot);
    
    stateManager->execute(dt);

}


void SoccerPlayer::updateBoneSpace(std::string uBoneName, U4DModel *uModel){
    
    //if (getCurrentPlayingAnimation()!=NULL) {
        
        U4DEngine::U4DMatrix4n animationBlenderMatrix=getCurrentPlayingAnimation()->modelerAnimationTransform;
        
        U4DEngine::U4DDualQuaternion boneSpace=getBoneAnimationSpace(uBoneName);
        
        U4DEngine::U4DMatrix4n boneMatrix=boneSpace.transformDualQuaternionToMatrix4n();
        
        boneMatrix=animationBlenderMatrix.inverse()*boneMatrix*animationBlenderMatrix;
        
        uModel->setLocalSpace(boneMatrix);
        
    //}
    
}


void SoccerPlayer::changeState(SoccerPlayerStateInterface* uState){
    
    stateManager->changeState(uState);
    
}


void SoccerPlayer::trackBall(){
    
    U4DEngine::U4DVector3n playerHeading=getPlayerHeading();
    
    playerHeading.normalize();
    
    U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
    
    U4DEngine::U4DVector3n directionOffset=playerHeading.cross(upVector);
    
    directionOffset+=playerHeading;
    
    directionOffset.y=0.0;
    
    //multiply the direction offset by the distance of the foot to the body
    directionOffset*leftRightFootOffset;
    
    U4DEngine::U4DVector3n ballPosition=soccerBallEntity->getAbsolutePosition();
    
    U4DEngine::U4DVector3n playerPosition=getAbsolutePosition();
    
    U4DEngine::U4DVector3n distanceVector=ballPosition-playerPosition;
    
    distanceVector-=directionOffset;
    
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

void SoccerPlayer::swingFeet(float uCycleAngle, float uAmplitude,double dt){
    /*
    if (getIsAnimationUpdatingKeyframe()) {
        
        U4DEngine::U4DTrigonometry trig;
        
        float angle=trig.degreesToRad(footSwingAngle);
        
        float yFootPosition=rightFoot->getLocalPosition().y;
        
        U4DEngine::U4DVector3n playerHeading=getPlayerHeading();
        
        playerHeading.normalize();
        
        U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
        
        U4DEngine::U4DVector3n directionOffsetVector=playerHeading.cross(upVector);
        
        directionOffsetVector*=leftRightFootOffset;
        
        U4DEngine::U4DVector3n newFootPosition=playerHeading*uAmplitude*cos(angle);
        
        footSwingAngle+=uCycleAngle;
        
        if (footSwingAngle>360.0) {
            footSwingAngle=0.0;
        }
    
        newFootPosition+=directionOffsetVector;
        
        newFootPosition.y=yFootPosition;
        
        //transform the new foot location into the player coordinate system
        U4DEngine::U4DMatrix3n m=getLocalMatrixOrientation();
        
        newFootPosition=newFootPosition*m;
        
        rightFoot->translateTo(newFootPosition);
        
    }
     */
}

bool SoccerPlayer::getFootCollidedWithBall(){
    
    return rightFoot->getModelHasCollided();
    
}

void SoccerPlayer::setFlagToPassBall(bool uValue){
    
    flagToPassBall=uValue;
    
}

bool SoccerPlayer::getFlagToPassBall(){
    
    return flagToPassBall;
    
}

void SoccerPlayer::setFootSwingInitAngle(float uAngle){
    
    footSwingAngle=uAngle;
    
}
