//
//  Player.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/28/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "Player.h"
#include "Foot.h"
#include "UserCommonProtocols.h"
#include "Ball.h"
#include "U4DGameConfigs.h"

#include "PlayerStateManager.h"
#include "PlayerStateInterface.h"

#include "PlayerStateIdle.h"
#include "PlayerStateDribbling.h"
#include "PlayerStateShooting.h"

Player::Player():dribblingDirection(0.0,0.0,-1.0),dribblingDirectionAccumulator(0.0, 0.0, 0.0),shootBall(false){
    
}

Player::~Player(){
    delete kineticAction;
    delete runningAnimation;
    
}

//init method. It loads all the rendering information among other things.
bool Player::init(const char* uModelName){
    
    if (loadModel(uModelName)) {
        
        stateManager=new PlayerStateManager(this);
        
        animationManager=new U4DEngine::U4DAnimationManager();

        kineticAction=new U4DEngine::U4DDynamicAction(this);

        kineticAction->enableKineticsBehavior();

        //kineticAction->enableCollisionBehavior();
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
        kineticAction->setGravity(zero);
        
        runningAnimation = new U4DEngine::U4DAnimation(this);

        if(loadAnimationToModel(runningAnimation, "running")){

        }
        
        shootingAnimation = new U4DEngine::U4DAnimation(this);

        if(loadAnimationToModel(shootingAnimation, "shooting")){
            shootingAnimation->setPlayContinuousLoop(false);
        }
        
        idleAnimation = new U4DEngine::U4DAnimation(this);

        if(loadAnimationToModel(idleAnimation, "idle")){

        }
        
        loadRenderingInformation();
        
        
        
        return true;
    
    }
    
    return false;
}

void Player::update(double dt){
    
    stateManager->update(dt);
//    if (state==chasing) {
//
//    }else if(state==dribbling){
//
//        U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
//
//        //applyForce(gameConfigs->getParameterForKey("dribblingSpeed"),dt);
//        Ball *ball=Ball::sharedInstance();
//
//        U4DEngine::U4DVector3n ballPos=ball->getAbsolutePosition();
//
//        ballPos.y=getAbsolutePosition().y;
//
//
//        arriveBehavior.setMaxSpeed(gameConfigs->getParameterForKey("arriveMaxSpeed"));
//        arriveBehavior.setTargetRadius(gameConfigs->getParameterForKey("arriveStopRadius"));
//        arriveBehavior.setSlowRadius(gameConfigs->getParameterForKey("arriveSlowRadius"));
//
//        U4DEngine::U4DVector3n finalVelocity=arriveBehavior.getSteering(kineticAction, ballPos);
//
//        if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
//            applyVelocity(finalVelocity, dt);
//            setMoveDirection(finalVelocity);
//
//        }else{
//
//            if(shootBall==true){
//
//                changeState(shooting);
//
//            }
//
//        }
//
//        updateFootSpaceWithAnimation(runningAnimation);
//
//        foot->kineticAction->resumeCollisionBehavior();
//
//        foot->setKickBallParameters(gameConfigs->getParameterForKey("dribblingBallSpeed"), dribblingDirection);
//
//    }else if(state==shooting){
//
//        shootBall=false;
//
//        updateFootSpaceWithAnimation(shootingAnimation);
//
//        foot->kineticAction->resumeCollisionBehavior();
//        if (shootingAnimation->getAnimationIsPlaying()==true && foot->kineticAction->getModelHasCollided()) {
//
//            foot->setKickBallParameters(80.0,dribblingDirection);
//
//        }
//
//        //if animation has stopped, the switch to idle
//        if (shootingAnimation->getAnimationIsPlaying()==false) {
//            changeState(idle);
//        }
//
//    }else if(state==idle){
//
//        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
//        kineticAction->setVelocity(zero);
//        kineticAction->setAngularVelocity(zero);
//    }
}

void Player::changeState(PlayerStateInterface* uState){
    
    stateManager->changeState(uState);
    
//    state=uState;
//
//    animationManager->removeAllAnimations();
//    U4DEngine::U4DAnimation *currentAnimation=nullptr;
//
//    switch (uState) {
//
//        case chasing:
//
//            currentAnimation=runningAnimation;
//
//            break;
//
//        case idle:
//
//            currentAnimation=idleAnimation;
//
//            break;
//
//        case dribbling:
//
//            currentAnimation=runningAnimation;
//
//            break;
//
//        case shooting:
//
//            currentAnimation=shootingAnimation;
//
//            break;
//
//        default:
//            break;
//
//    }
//
//    if(currentAnimation!=nullptr){
//        animationManager->setAnimationToPlay(currentAnimation);
//        animationManager->playAnimation();
//    }
    
}

PlayerStateInterface *Player::getCurrentState(){
    return stateManager->getCurrentState();
}

void Player::setFoot(Foot *uFoot){
    
    foot=uFoot;

    addChild(foot);
    
    //declare matrix for the gun space
    U4DEngine::U4DMatrix4n m;
    //original toe.R
    //2. Get the bone rest pose space
    if(getBoneRestPose("RightFoot",m)){

        //3. Apply space to gun
        foot->setLocalSpace(m);
        
    }
}

void Player::setEnableShooting(bool uValue){
    shootBall=uValue;
}

void Player::updateFootSpaceWithAnimation(U4DEngine::U4DAnimation *uAnimation){
    
    if (foot!=nullptr) {
        
        //declare matrix for the gun space
        U4DEngine::U4DMatrix4n m;
        //original is toe.R
        //2. Get the bone animation "runningAnimation" pose space
        if(getBoneAnimationPose("RightFoot",uAnimation,m)){
 
            //3. Apply space to gun
            foot->setLocalSpace(m);
            
        }
        
    }
    
}


void Player::applyForce(float uFinalVelocity, double dt){ 
    
    //force =m*(vf-vi)/dt
    
    //get the force direction and normalize
    dribblingDirection.normalize();
    
    //get mass
    float mass=kineticAction->getMass();
    
    //calculate force
    U4DEngine::U4DVector3n force=(dribblingDirection*uFinalVelocity*mass)/dt;
    
    //apply force to the character
    kineticAction->addForce(force);
    
    //set initial velocity to zero
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    kineticAction->setVelocity(zero);
    
}

void Player::applyVelocity(U4DEngine::U4DVector3n &uFinalVelocity, double dt){
    
    //force=m*(vf-vi)/dt
    
    //get mass
    float mass=kineticAction->getMass();
    
    //smooth out the motion of the camera by using a Recency Weighted Average.
    //The RWA keeps an average of the last few values, with more recent values being more
    //significant. The bias parameter controls how much significance is given to previous values.
    //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
    //A bias of 1 ignores the new value altogether.
    float biasMotionAccumulator=0.85;
    
    forceMotionAccumulator=forceMotionAccumulator*biasMotionAccumulator+uFinalVelocity*(1.0-biasMotionAccumulator);
    
    //calculate force
    U4DEngine::U4DVector3n force=(forceMotionAccumulator*mass)/dt;
    
    //apply force
    kineticAction->addForce(force);
    
    //set initial velocity to zero
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    kineticAction->setVelocity(zero);
    
}

void Player::setViewDirection(U4DEngine::U4DVector3n &uViewDirection){
    
    //declare an up vector
    U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
    
    float biasMotionAccumulator=0.95;
    
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
    
}

void Player::setMoveDirection(U4DEngine::U4DVector3n &uMoveDirection){
    
    U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
    
    uMoveDirection.normalize();

    //Get entity forward vector for the player
    U4DEngine::U4DVector3n v=getViewInDirection();

    v.normalize();
    
    //smooth out the motion of the camera by using a Recency Weighted Average.
    //The RWA keeps an average of the last few values, with more recent values being more
    //significant. The bias parameter controls how much significance is given to previous values.
    //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
    //A bias of 1 ignores the new value altogether.
    float biasMotionAccumulator=gameConfigs->getParameterForKey("biasMoveMotion");
    
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

}

void Player::setDribblingDirection(U4DEngine::U4DVector3n &uDribblingDirection){
    
        U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
        uDribblingDirection.normalize();
        
        float t=gameConfigs->getParameterForKey("dribblingDirectionSlerpValue");
        //smooth out the motion of the camera by using a Recency Weighted Average.
        //The RWA keeps an average of the last few values, with more recent values being more
        //significant. The bias parameter controls how much significance is given to previous values.
        //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
        //A bias of 1 ignores the new value altogether.
        float biasMotionAccumulator=0.95;
        
        dribblingDirectionAccumulator=dribblingDirectionAccumulator*biasMotionAccumulator+uDribblingDirection*(1.0-biasMotionAccumulator);
        
        dribblingDirectionAccumulator.normalize();

        dribblingDirection=dribblingDirection*t+dribblingDirectionAccumulator*(1.0-t);
    
}
