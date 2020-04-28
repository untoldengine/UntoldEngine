//
//  Player.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/22/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "Player.h"
#include "UserCommonProtocols.h"
#include "U4DRay.h"
#include "U4DRayCast.h"

Player::Player():motionAccumulator(0.0,0.0,0.0),hero(nullptr){
    
    //create the scheduler and timer objects used for the navigation
    navigationScheduler=new U4DEngine::U4DCallback<Player>;
    
    navigationTimer=new U4DEngine::U4DTimer(navigationScheduler);
    
}

Player::~Player(){
    
    navigationScheduler->unScheduleTimer(navigationTimer);
    
    delete navigationScheduler;
    
    delete navigationTimer;
    
}

bool Player::init(const char* uModelName){
    
    if (loadModel(uModelName)) {
        
        //enable shadows
        setEnableShadow(true);
        
        //set the state of the character
        setState(idle);
        
        //create the animation manager
        animationManager=new U4DEngine::U4DAnimationManager();
        
        //create the animation objects
        runningAnimation=new U4DEngine::U4DAnimation(this);
        patrolAnimation=new U4DEngine::U4DAnimation(this);
        patrolIdleAnimation=new U4DEngine::U4DAnimation(this);
        
        //load the animation data
        if(loadAnimationToModel(runningAnimation, "running")){
            
            
        }
        
        //load patrol animation data
        if(loadAnimationToModel(patrolAnimation,"patrol")){
            
        }
        
        //load patrol idle animation data
        if(loadAnimationToModel(patrolIdleAnimation,"patrolidle")){
            
        }
        
        //allow the character to move
        enableKineticsBehavior();
        
        //set gravity to zero
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
        setGravity(zero);
        
        //enable Collision
        enableCollisionBehavior();
        
        //set player as a collision sensor. Meaning only detection is enabled but not the collision response
        setIsCollisionSensor(true);
        
        //I am of type
        setCollisionFilterCategory(kPlayer);
        
        //I collide with type of
        setCollisionFilterMask(kBullet);
        
        //set default view of the character
        U4DEngine::U4DVector3n viewDirectionVector(0.0,0.0,-1.0);
        setEntityForwardVector(viewDirectionVector);
        
        //set mass of character
        initMass(1.0);
        
        //rotate the character
        rotateBy(0.0,180.0,0.0);
        
        //load the navigation mesh data
        navigationSystem=new U4DEngine::U4DNavigation();
        
        if(navigationSystem->loadNavMesh("Navmesh","navmeshAttributes.u4d")){
            
            //set parameters here
            navigationSystem->setPathRadius(0.5);
            navigationSystem->setPredictTime(0.8);
            navigationSystem->setNavigationSpeed(6.0);
            
        }
        
        //schedule the navigation scheduler
        navigationScheduler->scheduleClassWithMethodAndDelay(this, &Player::computeNavigation, navigationTimer, 3.0, true);
        
        //pause it for the time being
        navigationTimer->setPause(true);
        
        //send data to the GPU
        loadRenderingInformation();
        
        return true;
    }
    
    return false;
}

void Player::update(double dt){
    
    //check if the bullet has hit the player
    
    if(getModelHasCollided()){
        
        // Line 2. Get a list of entities it is colliding with
        for(auto n:getCollisionList()){
            
            // Line 3. Check if the entity is the bullet
            if (n->getCollidingTag().compare("bullet")==0) {
                
                std::cout<<"The enemy was hit"<<std::endl;
                
            }
            
        }
        
    }
    
    //check the state of the player
    if (state==patrol) {
    
        //is the player colliding with the map walls?
        if (testMapIntersection()) {
            
            changeState(idle);
        
        }else{
        
            //apply a force
            applyForce(7.0, dt);
            
            if(pistol!=nullptr){
                
                //declare a space
                U4DEngine::U4DMatrix4n m;
                
                if(getBoneAnimationPose("hand.R", patrolAnimation, m)){
                    
                    //apply space to pistol
                    
                    pistol->setLocalSpace(m);
                    
                }
            }
            
        }
        
    }else if(state==attack){
        
        //if object is in attack mode, it will get its velocity from the navigation system.
        
        U4DEngine::U4DVector3n finalVelocity=desiredNavigationVelocity();
        
        finalVelocity.y=0.0;
        
        if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
            
            applyVelocity(finalVelocity, dt);
            
            setViewDirection(finalVelocity);
            
        }
        
        
    }else if(state==patrolidle){
    
        if(pistol!=nullptr){
            
            //declare a space
            U4DEngine::U4DMatrix4n m;
            
            if(getBoneAnimationPose("hand.R", patrolIdleAnimation, m)){
                
                //apply space to pistol
                pistol->setLocalSpace(m);
                
            }
            
            //remove all velocities from the character
            U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
            
            setVelocity(zero);
            setAngularVelocity(zero);
            
        }
    
    }else if(state==idle){
        
        //remove all velocities from the character
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
        
        setVelocity(zero);
        setAngularVelocity(zero);
        
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
    
    previousState=state;
    
    //set new state
    setState(uState);
    
    //ask the animation manager to stop all animations
    animationManager->stopAnimation();
    
    U4DEngine::U4DAnimation *currentAnimation=nullptr;
    
    switch (uState) {
         
        case idle:
            //nothing happens
            
            break;
        
        case patrol:
            
            //change animation to patrol
            currentAnimation=patrolAnimation;
            
            break;
            
        case shooting:
            
            //change animation to shooting
            shoot();
            
            break;
            
        case attack:
            
            //change animation to running
            currentAnimation=runningAnimation;
            
            navigationTimer->setPause(false);
            
            break;
            
        case patrolidle:
            
            //change animation to patrol idle
            currentAnimation=patrolIdleAnimation;
            
            break;
            
            
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

void Player::setWeapon(Weapon *uPistol){
    
    pistol=uPistol;
    
    addChild(pistol);
    
    U4DEngine::U4DMatrix4n m;

    //2. Get the bone rest pose space
    if(getBoneRestPose("hand.R",m)){

    //3. Apply space to gun
    pistol->setLocalSpace(m);

    }
    
}

void Player::setMap(U4DEngine::U4DGameObject *uMap){
    map=uMap;
}

bool Player::testMapIntersection(){
    
    bool mapIntersection=false;
    
    //create a ray cast
    U4DEngine::U4DRayCast rayCast;
    U4DEngine::U4DTriangle hitTriangle;
    U4DEngine::U4DPoint3n intPoint;
    float intTime=0.0;
    
    //create a ray
    U4DEngine::U4DPoint3n playerPosition=getAbsolutePosition().toPoint();
    U4DEngine::U4DVector3n rayDirection=forceDirection;
    
    U4DEngine::U4DRay ray(playerPosition,rayDirection);
    
    if (rayCast.hit(ray, map, hitTriangle, intPoint, intTime)) {
        
        if(intTime<1.0){
            
            mapIntersection=true;
        }
    }
    
    return mapIntersection;
    
}


void Player::shoot(){
    pistol->shoot();
}

void Player::setHero(Player *uHero){
    hero=uHero;
}

void Player::computeNavigation(){
    
    if(hero!=nullptr){

        U4DEngine::U4DVector3n targetPosition=hero->getAbsolutePosition();

        navigationSystem->computePath(this, targetPosition);

    }
    
}

U4DEngine::U4DVector3n Player::desiredNavigationVelocity(){
    
    return navigationSystem->getSteering(this);
    
}
