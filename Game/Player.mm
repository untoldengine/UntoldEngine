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


Player::Player():motionAccumulator(0.0,0.0,0.0),rightFoot(nullptr),dribblingDirection(0.0,0.0,0.0),dribble(false),passBall(false){
    

}

Player::~Player(){
    
    
}

bool Player::init(const char* uModelName){
    
    if (loadModel(uModelName)) {
        
        //enable shadows
        //setEnableShadow(true);
        
        setNormalMapTexture("redkitnormal.png");
        
        //set the state of the character
        setState(idle);
        
        //create the animation manager
        animationManager=new U4DEngine::U4DAnimationManager();
        
        //create the animation objects
        runningAnimation=new U4DEngine::U4DAnimation(this);
        
        idleAnimation=new U4DEngine::U4DAnimation(this);
        
        dribblingAnimation=new U4DEngine::U4DAnimation(this);
        
        haltAnimation=new U4DEngine::U4DAnimation(this);
        
        passingAnimation=new U4DEngine::U4DAnimation(this);
        
        //load the animation data
        if(loadAnimationToModel(runningAnimation, "running")){
            
        }
        
        
        //load patrol idle animation data
        if(loadAnimationToModel(idleAnimation,"idle")){
            
        }
        
        //load the dribbling animation data
        if(loadAnimationToModel(dribblingAnimation, "rightdribble")){
            dribblingAnimation->setPlayContinuousLoop(false);
        }
        
        //load the halt animation data
        if(loadAnimationToModel(haltAnimation, "rightsolehalt")){
            haltAnimation->setPlayContinuousLoop(false);
        }
        
        //load the right pass animation data
        if(loadAnimationToModel(passingAnimation, "rightpass")){
            passingAnimation->setPlayContinuousLoop(false);
        }
        
        
        //allow the character to move
        enableKineticsBehavior();
        
        //set gravity to zero
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
        setGravity(zero);
        
        //enable Collision
        //enableCollisionBehavior();
        
        //set player as a collision sensor. Meaning only detection is enabled but not the collision response
        //setIsCollisionSensor(true);
        
        //I am of type
        //setCollisionFilterCategory(kPlayer);
        
        //I collide with type of bullet and player. The enemies can collide among themselves.
        //setCollisionFilterMask(kBullet|kPlayer);
        
        //set a tag
        //setCollidingTag("player");
        
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
    
    if(state==running){
        
        //apply a force
        applyForce(10.0, dt);
        
        updateFootSpaceWithAnimation(runningAnimation);
        
    }else if(state==arrive){
        
        //set the target entity to approach
        
        updateFootSpaceWithAnimation(runningAnimation);
        
        U4DEngine::U4DVector3n ballPosition=getBallPositionOffset();
        
        //change the y-position of the ball to be the same as the player
        ballPosition.y=getAbsolutePosition().y;
        
        //compute the final velocity
        U4DEngine::U4DVector3n finalVelocity=arriveBehavior.getSteering(this, ballPosition);
        
        //set the final y-component to zero
        finalVelocity.y=0.0;
        
        if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
            
            applyVelocity(finalVelocity, dt);
            setViewDirection(finalVelocity);
            
        }else{
            
            if(dribble==true){
                
                changeState(dribbling);
                
            }else if(passBall==true){
                
                changeState(passing);
                
            }else{
                
                changeState(halt);
                
            }
            
        }
        
    }else if(state==dribbling){
        
        Ball *ball=Ball::sharedInstance();
        
        ball->setKickVelocity(15.0);
        
        if(forceDirection==U4DEngine::U4DVector3n(0.0,0.0,0.0)){
            
            U4DEngine::U4DVector3n viewDir=getViewInDirection();
            
            ball->setForceDirection(viewDir);
            
        }else{
            ball->setForceDirection(dribblingDirection);
        }
    
        //apply a force
        applyForce(1.0, dt);
        
        updateFootSpaceWithAnimation(dribblingAnimation);
        
        //check the distance between the player and the ball
        U4DEngine::U4DVector3n ballPosition=getBallPositionOffset();
        ballPosition.y=getAbsolutePosition().y;
        
        float distanceToBall=(ballPosition-getAbsolutePosition()).magnitude();
        
        if (distanceToBall>0.5) {
        
            changeState(arrive);
            
        }
        
    }else if(state==halt){
        
        updateFootSpaceWithAnimation(haltAnimation);
        
        Ball *ball=Ball::sharedInstance();
        ball->setKickVelocity(0.0);
        ball->changeState(stopped);
        
        //remove all velocities from the character
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
        
        setVelocity(zero);
        setAngularVelocity(zero);
        
        if(dribble==true){
            
            changeState(dribbling);
            
        }
        
    }else if(state==passing){
        
        Ball *ball=Ball::sharedInstance();
        
        ball->setKickVelocity(47.0);
        
        if(forceDirection==U4DEngine::U4DVector3n(0.0,0.0,0.0)){
            
            U4DEngine::U4DVector3n viewDir=getViewInDirection();
            
            ball->setForceDirection(viewDir);
            
        }else{
            ball->setForceDirection(dribblingDirection);
        }
        
        //apply a force
        applyForce(5.0, dt);
        
        updateFootSpaceWithAnimation(passingAnimation);
        
        //if animation has stopped, the switch to idle
        if (passingAnimation->getAnimationIsPlaying()==false) {
            
            closestPlayerToIntersect();
            
            changeState(supporting);
        }
        
        passBall=false;
        
    }else if(state==supporting){
        
        U4DEngine::U4DFlock flockBehavior;
        
        flockBehavior.setMaxSpeed(5.0);
        
        std::vector<U4DDynamicModel*> tempNeighbors;
        for(const auto &n:teammates){
            tempNeighbors.push_back(n);
        }

        U4DEngine::U4DVector3n desiredVelocity=flockBehavior.getSteering(this, tempNeighbors);
        
        if(!(desiredVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
        
            desiredVelocity.y=0.0;
            applyVelocity(desiredVelocity, dt);
            setViewDirection(desiredVelocity);
        }
        
    }else if(state==pursuit){
        
        updateFootSpaceWithAnimation(runningAnimation);
        
        Ball *ball=Ball::sharedInstance();
        
        U4DEngine::U4DVector3n finalVelocity=pursuitBehavior.getSteering(this, ball);
        
        //set the final y-component to zero
        finalVelocity.y=0.0;
        
        if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
            
            applyVelocity(finalVelocity, dt);
            setViewDirection(finalVelocity);
            
        }
        
        //check the distance between the player and the ball
        U4DEngine::U4DVector3n ballPosition=getBallPositionOffset();
        ballPosition.y=getAbsolutePosition().y;
        
        float distanceToBall=(ballPosition-getAbsolutePosition()).magnitude();
        
        if (distanceToBall<2.0) {
        
            changeState(arrive);
            
        }
        
        
        
    }else if(state==idle){
        
        updateFootSpaceWithAnimation(idleAnimation);
        
        //remove all velocities from the character
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
        
        setVelocity(zero);
        setAngularVelocity(zero);
        
    }
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

void Player::setState(int uState){
    
    state=uState;
    
}

int Player::getState(){
    
    return state;
}

int Player::getPreviousState(){
    
    return previousState;
   
}

void Player::changeState(int uState){
    
    rightFoot->resumeCollisionBehavior();
    
    previousState=state;
    
    //set new state
    setState(uState);
    
    //ask the animation manager to stop all animations
    animationManager->stopAnimation();
    
    U4DEngine::U4DAnimation *currentAnimation=nullptr;
    
    switch (uState) {
         
        case idle:
            //nothing happens
            currentAnimation=idleAnimation;
            
            break;
        
        
        case running:
            
            //change animation to running
            currentAnimation=runningAnimation;
            
            break;
            
        case halt:
        
        //change animation to halt
        currentAnimation=haltAnimation;
        
        break;
        
        case arrive:
            
            rightFoot->pauseCollisionBehavior();
            
            //change animation to running
            currentAnimation=runningAnimation;
            
            //set speed
            arriveBehavior.setMaxSpeed(15.0);

            //set the distance to stop
            arriveBehavior.setTargetRadius(0.5);

            //set the distance to start slowing down
            arriveBehavior.setSlowRadius(1.0);
            
            break;
            
        case dribbling:
        {
            //change animaiton to dribbling
            currentAnimation=dribblingAnimation;
        
            //Make all teammates as supporting player
            for(const auto &n:teammates){
                n->changeState(supporting);
            }
            
        }
            break;
            
        case passing:
        {
            //change animation to passing
            currentAnimation=passingAnimation;
            
        }
            break;
            
        case pursuit:
        {
            rightFoot->pauseCollisionBehavior();
            
            pursuitBehavior.setMaxSpeed(15.0);
            
            currentAnimation=runningAnimation;
        }
            
            break;
            
        case supporting:
        {
            currentAnimation=runningAnimation;
            
        }
            
        default:
            break;
    }
    
    if (currentAnimation!=nullptr) {
        
        animationManager->setAnimationToPlay(currentAnimation);
        animationManager->playAnimation();
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
    
    //calculate force
    U4DEngine::U4DVector3n force=(uFinalVelocity*mass)/dt;
    
    //apply force
    addForce(force);
    
    //set initial velocity to zero
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    setVelocity(zero);
    
}

void Player::setViewDirection(U4DEngine::U4DVector3n &uViewDirection){
    
    //declare an up vector
    U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
    
    float biasMotionAccumulator=0.9;
    
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

void Player::setEnableDribbling(bool uValue){
    dribble=uValue;
}

void Player::setEnablePassing(bool uValue){
    passBall=uValue;
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

void Player::addTeammates(std::vector<Player*> uTeammates){

    for(const auto &n:uTeammates){
        
        //make sure not to add itself as a teammate
        if(n!=this){
            teammates.push_back(n);
        }
    }
 
}

void Player::closestPlayerToIntersect(){
    
    Ball *ball=Ball::sharedInstance();
    
    float maxDistanceToBall=1000.0;
    Player *closestPlayer=nullptr;
    
    for (const auto &n:teammates) {

        //distace to ball
        float d=(ball->getAbsolutePosition()-n->getAbsolutePosition()).magnitude();
        
        if((n!=this)&&(d<maxDistanceToBall)){
                        
            maxDistanceToBall=d;
            closestPlayer=n;
            
        }
    }
    
    if(closestPlayer!=nullptr){
        
        //chose the player closest to intersect the ball. For now, just do this.
        closestPlayer->changeState(pursuit);
        
        //assign it as the active player
        U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
        
        U4DEngine::U4DScene *scene=sceneManager->getCurrentScene();
        
        LevelOneLogic *levelOneLogic=dynamic_cast<LevelOneLogic*>(scene->gameModel);
        
        levelOneLogic->setActivePlayer(closestPlayer);
        
    }
    
}
