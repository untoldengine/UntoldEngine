//
//  Bullet.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/22/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "Bullet.h"
#include "UserCommonProtocols.h"

Bullet::Bullet(){
    
    //create the callback
    selfDestroyScheduler=new U4DEngine::U4DCallback<Bullet>;
    
    //create the timer
    selfDestroyTimer=new U4DEngine::U4DTimer(selfDestroyScheduler);
    
}

Bullet::~Bullet(){
    
    //In the class destructor, make sure to delete the callback and timer as follows
        
    selfDestroyScheduler->unScheduleTimer(selfDestroyTimer);
    
    delete selfDestroyScheduler;
    
    delete selfDestroyTimer;
    
}

bool Bullet::init(const char* uModelName){
    
    if (loadModel(uModelName)) {
        
        setPipeline("nonvisible");
        
        //enable the physics engine
        enableKineticsBehavior();

        //set gravity to zero
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
        setGravity(zero);
        
        enableCollisionBehavior();

        setIsCollisionSensor(true);

        setCollisionFilterCategory(kBullet);

        setCollisionFilterMask(kEnemySoldier);

        setCollidingTag("bullet");
        
        loadRenderingInformation();
        
        return true;
        
    }
    
    return false;
}

void Bullet::update(double dt){
    
    if(getModelHasCollided()){
     
        pauseCollisionBehavior();
        
    }
    
    if (state==shot) {
        
        U4DEngine::U4DVector3n pos=getAbsolutePosition();

        particleSystem->translateTo(pos);
        
        applyForce(100.0,dt);
        
    }
    
}

void Bullet::applyForce(float uFinalVelocity, double dt){
    
    //force=m*(vf-vi)/dt
    
    //get the force direction
    forceDirection.normalize();
    
    //get mass
    float mass=getMass();
    
    //calculate force
    U4DEngine::U4DVector3n force=(forceDirection*uFinalVelocity*mass)/dt;
    
    //apply force to the character
    addForce(force);
    
    //set inital velocity to zero
    
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    setVelocity(zero);
    
}

void Bullet::setForceDirection(U4DEngine::U4DVector3n &uForceDirection){
    
    forceDirection=uForceDirection;
    
}

void Bullet::setSchedulerToDestroy(){
    
    selfDestroyScheduler->scheduleClassWithMethodAndDelay(this, &Bullet::selfDestroy, selfDestroyTimer, 1.0,false);
    
}

void Bullet::selfDestroy(){
    
    changeState(destroy);

    U4DEngine::U4DEntity *parent=getParent();

    if(particleSystem!=nullptr){

        particleSystem->stop();
        
        parent->removeChild(particleSystem);

        delete particleSystem;

        particleSystem=nullptr;

    }

    parent->removeChild(this);

    delete this;
    
}

void Bullet::createParticle(const char* uParticleFile){
    
    U4DEngine::U4DEntity *parent=getParent();
    
    particleSystem=new U4DEngine::U4DParticleSystem();
    
    if (particleSystem->loadParticle(uParticleFile)) {
        
        particleSystem->setEnableAdditiveRendering(true); //set true by default
        particleSystem->setEnableNoise(true); //set false by default
        particleSystem->setNoiseDetail(2.0); //ranges from [2-16]
        
        particleSystem->loadRenderingInformation();
        
        //add the particle system to the scenegraph with the corresponding z-depth order
        parent->addChild(particleSystem,getZDepth());
        
        U4DEngine::U4DVector3n pos=getAbsolutePosition();
        
        particleSystem->translateTo(pos);
        
        //initiate the particle's emission
        particleSystem->play();
        
    }
}

void Bullet::changeState(int uState){
    
    //set state
    setState(uState);
    
    switch (uState) {
            
        case shot:

            createParticle("redBulletEmitter");

            setSchedulerToDestroy();
            
            break;


        default:
            break;

    }
}

void Bullet::setState(int uState){
    state=uState;
}

int Bullet::getState(){
    return state;
}
