//
//  Player.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/7/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "Player.h"
#include "UserCommonProtocols.h"
#include "U4DWorld.h"
#include "U4DGameModelInterface.h"
#include "U4DGameModel.h"
#include "U4DLayerManager.h"
#include "Rifle.h"
#include "U4DRayCast.h"
#include "U4DRay.h"

Player::Player():mapLevel(nullptr),playerShooting(false),hero(nullptr),motionAccumulator(0.0,0.0,0.0){
    
    
    
}

Player::~Player(){
    
}

bool Player::init(const char* uModelName){
    
    if(loadModel(uModelName)){
        
        
        //enable the physics engine
        enableKineticsBehavior();

        //set gravity to zero
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
        setGravity(zero);
        
        //set an animation manager
        animationManager=new U4DEngine::U4DAnimationManager();

        //create anim object
        idleAnimation=new U4DEngine::U4DAnimation(this);
        patrolAnimation=new U4DEngine::U4DAnimation(this);
        shootingAnimation=new U4DEngine::U4DAnimation(this);
        deadAnimation=new U4DEngine::U4DAnimation(this);
            
        //load animation
        if(loadAnimationToModel(idleAnimation, "idle")){


        }
        
        if(loadAnimationToModel(patrolAnimation, "patrol")){


        }
        
        if(loadAnimationToModel(shootingAnimation, "shoot")){

            //The shoot animation should only play once and then stop
            shootingAnimation->setPlayContinuousLoop(false);

        }
        
        if(loadAnimationToModel(deadAnimation, "dead")){

            //The dead animation should only play once and then stop
            deadAnimation->setPlayContinuousLoop(false);

        }
        
        //enable collision behavior
        enableCollisionBehavior();

        //since we don't need the exact location of collision, just to detect if it has collided, then we can set the object as a sensor
        setIsCollisionSensor(true);

        //create a rifle object and add it to the scenegraph of the model
        rifle=new Rifle();
        
        if(rifle->init("rifle")){
            addChild(rifle);
        }
        
        return true;
    }
    
    return false;
    
}

void Player::update(double dt){

    if (state==patrol && hero!=nullptr) {

        //get the navigation velocity computed by the Game Logic, i.e., DemoLogic
        //Check if the resulting velocity is set to zero. Do this as a a safeguard. I have to fix this issue.
        if(!(navigationVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){

            applyVelocity(navigationVelocity, dt);
            setViewDirection(navigationVelocity);

        }

        //Link the rifle to the motion of the animation
        //declare matrix for the gun space
        U4DEngine::U4DMatrix4n m;

        //Get the bone animation for "patrol" pose space

        if (getBoneAnimationPose("wrist.R", patrolAnimation, m)) {

            //Apply space to gun
            rifle->setLocalSpace(m);

        }

        if((hero->getAbsolutePosition()-getAbsolutePosition()).magnitude()<5.0){

            //remove velocities
            U4DEngine::U4DVector3n zero(0.0,0.0,0.0);

            setVelocity(zero);
            setAngularVelocity(zero);

            changeState(shooting);
        }

    }else if(state==stealth){
    
        //do a wall test intersection. If the model is colliding, then change the state to idle
        if(!testMapIntersection()){
            U4DEngine::U4DVector3n forceDir=forceDirection*8.0;
            applyVelocity(forceDir, dt);

        }else{
            changeState(idle);
        }
        
        //link the rifle to the motion of the animation
        //declare matrix for the gun space
        U4DEngine::U4DMatrix4n m;

        //Get the bone animation for "patrol" pose space

        if (getBoneAnimationPose("wrist.R", patrolAnimation, m)) {

            //Apply space to gun
            rifle->setLocalSpace(m);

        }
        
    }else if(state==shooting){
        
        //link the rifle to the motion of the animation
        //declare matrix for the gun space
        U4DEngine::U4DMatrix4n m;

        //Get the bone animation for "running" pose space

        if (getBoneAnimationPose("wrist.R", patrolAnimation, m)) {

            //Apply space to gun
            rifle->setLocalSpace(m);

        }
        
        //check if the shooting animation is playing. If so, then shoot the bullet
        if(shootingAnimation->getAnimationIsPlaying() && shootingAnimation->getCurrentKeyframe()>0 && playerShooting==false){
                    
            shoot();

            playerShooting=true;
            
        }else if(shootingAnimation->getAnimationIsPlaying()==false){

            playerShooting=false;
            changeState(previousState);
            
        }

    }else if(state==dead){
        
        //declare matrix for the gun space
        U4DEngine::U4DMatrix4n m;

        //Get the bone animation for "running" pose space

        if (getBoneAnimationPose("wrist.R", deadAnimation, m)) {

            //Apply space to gun
            rifle->setLocalSpace(m);

        }

        //remove velocities
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);

        setVelocity(zero);
        setAngularVelocity(zero);
        
    }else if (state==idle){

        //declare matrix for the gun space
        U4DEngine::U4DMatrix4n m;

        //Get the bone animation for "running" pose space

        if (getBoneAnimationPose("wrist.R", idleAnimation, m)) {

            //Apply space to gun
            rifle->setLocalSpace(m);

        }

        //remove velocities
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);

        setVelocity(zero);
        setAngularVelocity(zero);

    }
    
}

void Player::setHero(Player *uHero){
    hero=uHero;
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

bool Player::testMapIntersection(){
    
    bool wallIntersection=false;
    
    if (mapLevel!=nullptr) {
        
        //create a ray cast
        U4DEngine::U4DRayCast rayCast;
        U4DEngine::U4DTriangle hitTriangle;
        U4DEngine::U4DPoint3n intPoint;
        float intTime=0.0;
        
        //create a ray
        U4DEngine::U4DPoint3n pos=getAbsolutePosition().toPoint();
        U4DEngine::U4DVector3n rayDirection=forceDirection;
        
        U4DEngine::U4DRay ray(pos,rayDirection);
        
        if(rayCast.hit(ray,mapLevel,hitTriangle,intPoint, intTime)){
            
                if(intTime<0.7){
                   
                    wallIntersection=true;
                
                }

        }
        
    }

    return wallIntersection;
    
}

void Player::testRampIntersection(){
    
}

void Player::changeState(int uState){
    
    //set previous state
    previousState=state;

    //set state
    setState(uState);

    //We use the animation manager to switch between animations.
    //ask the animation manager to remove the currently playing animation
    animationManager->removeCurrentPlayingAnimation();

    U4DEngine::U4DAnimation *currentAnimation=nullptr;

    switch (uState) {

        case idle:
        {

            currentAnimation=idleAnimation;

        }
            break;

        case patrol:

            currentAnimation=patrolAnimation;

            break;
            
        case stealth:

            currentAnimation=patrolAnimation;

            break;

        case shooting:
            
            currentAnimation=shootingAnimation;
            
            break;
            
        case dead:
            
            currentAnimation=deadAnimation;
            
            break;

        default:
            break;
    }

    //ask the animation to play the next animation
    if (currentAnimation!=nullptr) {
        animationManager->setAnimationToPlay(currentAnimation);
        animationManager->playAnimation();
    }
    
}

void Player::applyForce(float uFinalVelocity, double dt){
    
    //force=m*(vf-vi)/dt
    
    //get the force direction
    forceDirection.normalize();
    
    //get mass
    float mass=getMass();
    
    //calculate force
    U4DEngine::U4DVector3n force=(forceDirection*uFinalVelocity*mass)/dt;
    
    force=rampOrientation*force;
    
    //apply force to the character
    addForce(force);
    
    //set inital velocity to zero
    
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


void Player::setForceDirection(U4DEngine::U4DVector3n &uForceDirection){
    
    forceDirection=uForceDirection;
    
}

void Player::setMap(U4DEngine::U4DGameObject *uMap){
    mapLevel=uMap;
}

void Player::shoot(){
    
    U4DEngine::U4DVector3n bulletDirection=getViewInDirection();
    
    rifle->shoot(bulletDirection);
    
}

void Player::applyVelocity(U4DEngine::U4DVector3n &uFinalVelocity, double dt){
    
    //force=m*(vf-vi)/dt
    
    //get mass
    float mass=getMass();
    
    //calculate force
    U4DEngine::U4DVector3n force=(uFinalVelocity*mass)/dt;
    
    //apply force to the character
    addForce(force);
    
    //set inital velocity to zero
    
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    setVelocity(zero);

}

void Player::setNavigationVelocity(U4DEngine::U4DVector3n &uNavigationVelocity){
    navigationVelocity=uNavigationVelocity;
}

