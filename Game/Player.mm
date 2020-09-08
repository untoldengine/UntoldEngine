//
//  Player.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/22/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "Player.h"
#include "UserCommonProtocols.h"
#include "Foot.h"
#include "Ball.h"
#include "U4DSceneManager.h"
#include "U4DScene.h"
#include "LevelOneLogic.h"
#include "PathAnalyzer.h"
#include "Team.h"

#include "PlayerStateManager.h"
#include "PlayerStateInterface.h"

#include "PlayerStateIdle.h"
#include "PlayerStateChase.h"
#include "PlayerStateDribble.h"
#include "PlayerStateHalt.h"
#include "PlayerStatePass.h"
#include "PlayerStateShoot.h"
#include "PlayerStateTap.h"
#include "PlayerStateIntercept.h"
#include "PlayerStateGroupNav.h"

Player::Player():motionAccumulator(0.0,0.0,0.0),rightFoot(nullptr),dribblingDirection(0.0,0.0,0.0),dribbleBall(false),passBall(false),shootBall(false),standTackleOpponent(false),haltBall(false),forceMotionAccumulator(0.0,0.0,0.0),team(nullptr),playerIndex(0){
    

}

Player::~Player(){
    
    
}

bool Player::init(const char* uModelName){
    
    if (loadModel(uModelName)) {
        
        //enable shadows
        setEnableShadow(true);
        
        setNormalMapTexture("redkitnormal.png");
        
        //setShader("vertexKitShader","fragmentKitShader");
        
        //Default Uniform
        U4DEngine::U4DVector4n jersey(0.8,0.66,0.07,0.0);
        U4DEngine::U4DVector4n shorts(0.07,0.28,0.61,0.0);
        U4DEngine::U4DVector4n cleats(0.0,0.0,0.0,0.0);
        U4DEngine::U4DVector4n socks(0.9,0.9,0.9,0.0);
        
        updateShaderParameterContainer(0,jersey);
        updateShaderParameterContainer(1,shorts);
        updateShaderParameterContainer(2,cleats);
        updateShaderParameterContainer(3,socks);
        
        //set state manager
        stateManager=new PlayerStateManager(this);
        
        changeState(PlayerStateIdle::sharedInstance());
        
        //create the animation manager
        animationManager=new U4DEngine::U4DAnimationManager();
        
        //create the animation objects
        runningAnimation=new U4DEngine::U4DAnimation(this);
        
        idleAnimation=new U4DEngine::U4DAnimation(this);
        
        dribblingAnimation=new U4DEngine::U4DAnimation(this);
        
        haltAnimation=new U4DEngine::U4DAnimation(this);
        
        passingAnimation=new U4DEngine::U4DAnimation(this);
        
        shootingAnimation=new U4DEngine::U4DAnimation(this);
        
        standTackleAnimation=new U4DEngine::U4DAnimation(this);
        
        containAnimation=new U4DEngine::U4DAnimation(this);
        
        tapAnimation=new U4DEngine::U4DAnimation(this);
        
        //load the animation data
        if(loadAnimationToModel(runningAnimation, "running")){
            
        }
        
        
        //load patrol idle animation data
        if(loadAnimationToModel(idleAnimation,"idle")){
            
        }
        
        //load the dribbling animation data
        if(loadAnimationToModel(dribblingAnimation, "rightdribble")){
            //dribblingAnimation->setPlayContinuousLoop(false);
        }
        
        //load the halt animation data
        if(loadAnimationToModel(haltAnimation, "rightsolehalt")){
            haltAnimation->setPlayContinuousLoop(false);
        }
        
        //load the right pass animation data
        if(loadAnimationToModel(passingAnimation, "rightpass")){
            passingAnimation->setPlayContinuousLoop(false);
        }
        
        //load the shooting animation data
        if(loadAnimationToModel(shootingAnimation, "shooting")){
            shootingAnimation->setPlayContinuousLoop(false);
        }
        
        //load the stand tackle animation data
        if(loadAnimationToModel(standTackleAnimation,"standtackle")){
            
            standTackleAnimation->setPlayContinuousLoop(false);
            
        }
        
        //load the contain animation data
        if(loadAnimationToModel(containAnimation, "forwardcontain")){
            
        }
        
        //load the contain animation data
        if(loadAnimationToModel(tapAnimation, "righttap")){
            tapAnimation->setPlayContinuousLoop(false);
        }
        
        
        //allow the character to move
        enableKineticsBehavior();
        
        //set gravity to zero
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
        setGravity(zero);
        
        //enable Collision
        enableCollisionBehavior();
        
        //setBroadPhaseBoundingVolumeVisibility(true);
        
        //set player as a collision sensor. Meaning only detection is enabled but not the collision response
        setIsCollisionSensor(true);
        
        //I am of type
        setCollisionFilterCategory(kPlayer);
        
        //I collide with type of bullet and player. The enemies can collide among themselves.
        setCollisionFilterMask(kPlayer);
        
        //set a tag
        setCollidingTag("player");
        
        //set default view of the character
        U4DEngine::U4DVector3n viewDirectionVector(0.0,0.0,-1.0);
        setEntityForwardVector(viewDirectionVector);
        
        //set mass of character
        initMass(1.0);
        
        //send data to the GPU
        loadRenderingInformation();
        
        //render the right foot
        rightFoot=new Foot(this);
        
        if(rightFoot->init("rightfoot")){
            
            setFoot(rightFoot);
            
        }
        
        return true;
    }
    
    return false;
    
}

void Player::update(double dt){
    
    stateManager->update(dt);
    
}

void Player::changeState(PlayerStateInterface *uState){
    
    stateManager->safeChangeState(uState);
    
}


PlayerStateInterface *Player::getCurrentState(){
    
    return stateManager->getCurrentState();
}

PlayerStateInterface *Player::getPreviousState(){
    
    return stateManager->getPreviousState();
}

void Player::setFoot(Foot *uRightFoot){
    
    rightFoot=uRightFoot;
    
    //make the right foot a child of the player
    addChild(rightFoot);
    
    //declare matrix for the gun space
    U4DEngine::U4DMatrix4n m;

    //2. Get the bone rest pose space
    if(getBoneRestPose("toe.R",m)){

        //3. Apply space to gun
        rightFoot->setLocalSpace(m);
        
    }
        
}

void Player::setForceDirection(U4DEngine::U4DVector3n &uForceDirection){
    
    forceDirection=uForceDirection;
    
}

void Player::setDribblingDirection(U4DEngine::U4DVector3n &uDribblingDirection){
    
    dribblingDirection=uDribblingDirection;
    
}



void Player::applyForce(float uFinalVelocity, double dt){
    
    //force =m*(vf-vi)/dt
    
    //get the force direction and normalize
    forceDirection.normalize();
    
    //get mass
    float mass=getMass();
    
    //calculate force
    U4DEngine::U4DVector3n force=(forceDirection*uFinalVelocity*mass)/dt;
    
    //apply force to the character
    addForce(force);
    
    //set initial velocity to zero
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    setVelocity(zero);
    
}

void Player::applyVelocity(U4DEngine::U4DVector3n &uFinalVelocity, double dt){
    
    //force=m*(vf-vi)/dt
    
    //get mass
    float mass=getMass();
    
    //smooth out the motion of the camera by using a Recency Weighted Average.
    //The RWA keeps an average of the last few values, with more recent values being more
    //significant. The bias parameter controls how much significance is given to previous values.
    //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
    //A bias of 1 ignores the new value altogether.
    float biasMotionAccumulator=0.1;
    
    forceMotionAccumulator=forceMotionAccumulator*biasMotionAccumulator+uFinalVelocity*(1.0-biasMotionAccumulator);
    
    //calculate force
    U4DEngine::U4DVector3n force=(forceMotionAccumulator*mass)/dt;
    
    //apply force
    addForce(force);
    
    //set initial velocity to zero
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    setVelocity(zero);
    
}

void Player::setViewDirection(U4DEngine::U4DVector3n &uViewDirection){
    
    //declare an up vector
    U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
    
    float biasMotionAccumulator=0.0;
    
    motionAccumulator=motionAccumulator*biasMotionAccumulator+uViewDirection*(1.0-biasMotionAccumulator);
    
    motionAccumulator.normalize();
    
    U4DEngine::U4DVector3n viewDir=getEntityForwardVector();
    
    U4DEngine::U4DMatrix3n m=getAbsoluteMatrixOrientation();
    
    //transform the upvector
    upVector=m*upVector;
    
    U4DEngine::U4DVector3n posDir=viewDir.cross(upVector);
    
    float angle=motionAccumulator.angle(viewDir);
    
    if(motionAccumulator.dot(posDir)>0.0){
        
        angle*=-1.0;
        
    }
    
    U4DEngine::U4DQuaternion q(angle,upVector);
    
    rotateTo(q);
    
    //set the force direction
    U4DEngine::U4DVector3n forceDir=getViewInDirection();

    forceDir.y=0.0;

    forceDir.normalize();

    setForceDirection(forceDir);
    
}

void Player::setMoveDirection(U4DEngine::U4DVector3n &uMoveDirection){
    
    uMoveDirection.normalize();

    //Get entity forward vector for the player
    U4DEngine::U4DVector3n v=getViewInDirection();

    v.normalize();
    
    //smooth out the motion of the camera by using a Recency Weighted Average.
    //The RWA keeps an average of the last few values, with more recent values being more
    //significant. The bias parameter controls how much significance is given to previous values.
    //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
    //A bias of 1 ignores the new value altogether.
    float biasMotionAccumulator=0.0;
    
    motionAccumulator=motionAccumulator*biasMotionAccumulator+uMoveDirection*(1.0-biasMotionAccumulator);
    
    motionAccumulator.normalize();

    //set an up-vector
    U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);

    U4DEngine::U4DMatrix3n m=getAbsoluteMatrixOrientation();

    //transform the up vector
    upVector=m*upVector;

    U4DEngine::U4DVector3n posDir=v.cross(upVector);

    //Get the angle between the analog joystick direction and the view direction
    float angle=v.angle(motionAccumulator);

    //if the dot product between the joystick-direction and the positive direction is less than zero, flip the angle
    if(motionAccumulator.dot(posDir)>0.0){
        angle*=-1.0;
    }
    
    //create a quaternion between the angle and the upvector
    U4DEngine::U4DQuaternion newOrientation(angle,upVector);

    //Get current orientation of the player
    U4DEngine::U4DQuaternion modelOrientation=getAbsoluteSpaceOrientation();

    //create slerp interpolation
    U4DEngine::U4DQuaternion p=modelOrientation.slerp(newOrientation, 1.0);

    //rotate the character
    rotateBy(p);

    //set the force direction
    U4DEngine::U4DVector3n forceDir=getViewInDirection();

    forceDir.y=0.0;

    forceDir.normalize();

    setForceDirection(forceDir);

}

void Player::setEnableDribbling(bool uValue){
    dribbleBall=uValue;
}

void Player::setEnablePassing(bool uValue){
    passBall=uValue;
}

void Player::setEnableShooting(bool uValue){
    shootBall=uValue;
}

void Player::setEnableStandTackle(bool uValue){
    standTackleOpponent=uValue;
}

void Player::setEnableHalt(bool uValue){
    haltBall=uValue;
    
}

U4DEngine::U4DVector3n Player::getBallPositionOffset(){
    
    Ball *ball=Ball::sharedInstance();
    
    U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
    U4DEngine::U4DVector3n viewDir=getViewInDirection();
    
    U4DEngine::U4DVector3n leftHand=viewDir.cross(upVector);
    
    U4DEngine::U4DVector3n ballPosition=ball->getAbsolutePosition();
    
    U4DEngine::U4DVector3n ballPositionOffset=ballPosition+leftHand*0.5;
    
    return ballPositionOffset;
    
}

void Player::updateFootSpaceWithAnimation(U4DEngine::U4DAnimation *uAnimation){
    
    if (rightFoot!=nullptr) {
        
        //declare matrix for the gun space
        U4DEngine::U4DMatrix4n m;

        //2. Get the bone animation "runningAnimation" pose space
        if(getBoneAnimationPose("toe.R",uAnimation,m)){

            //3. Apply space to gun
            rightFoot->setLocalSpace(m);
            
        }
        
    }
    
}

void Player::addToTeam(Team *uTeam){
    
    team=uTeam;
    
}

Team *Player::getTeam(){
    return team;
}

U4DEngine::U4DAnimationManager *Player::getAnimationManager(){
    return animationManager;
}

U4DEngine::U4DAnimation *Player::getAnimationToPlay(){
    
    U4DEngine::U4DAnimation *currentAnimation=nullptr;
    
    //get current state animation
    if(getCurrentState()==PlayerStateIdle::sharedInstance()){
       
        currentAnimation=idleAnimation;
         
    }else if (getCurrentState()==PlayerStateChase::sharedInstance() || getCurrentState()==PlayerStateIntercept::sharedInstance() || getCurrentState()==PlayerStateGroupNav::sharedInstance()){
        
        currentAnimation=runningAnimation;
        
    }else if (getCurrentState()==PlayerStateDribble::sharedInstance()){
        
        currentAnimation=dribblingAnimation;
        
    }else if (getCurrentState()==PlayerStateHalt::sharedInstance()){
        
        currentAnimation=haltAnimation;
        
    }else if (getCurrentState()==PlayerStatePass::sharedInstance()){
        
        currentAnimation=passingAnimation;
        
    }else if (getCurrentState()==PlayerStateShoot::sharedInstance()){
        
        currentAnimation=shootingAnimation;
        
    }else if(getCurrentState()==PlayerStateTap::sharedInstance()){
        currentAnimation=tapAnimation;
    }
    
    return currentAnimation;
    
}

void Player::handleMessage(Message &uMsg){
    stateManager->handleMessage(uMsg);
}


void Player::setPlayerIndex(int uIndex){
    playerIndex=uIndex;
}

int Player::getPlayerIndex(){
    
    return playerIndex;
    
}

