//
//  Bullet.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/26/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "Bullet.h"
#include "UserCommonProtocols.h"

Bullet::Bullet():forceDirection(0.0,0.0,0.0){
    
    //create scheduler and timer
    scheduler=new U4DEngine::U4DCallback<Bullet>;
    
    timer=new U4DEngine::U4DTimer(scheduler);
    
}

Bullet::~Bullet(){
    
    //delete scheduler and timer
    scheduler->unScheduleTimer(timer);
    
    delete scheduler;
    
    delete timer;
    
}

bool Bullet::init(const char* uModelName){
    
    if(loadModel(uModelName)){
        
        //set invisible shader
        setShader("vertexNonVisibleShader","fragmentNonVisibleShader");
        
        //disable shadows
        setEnableShadow(false);
        
        //enable kinetic behavior
        enableKineticsBehavior();
        
        //enable Collision
        enableCollisionBehavior();
        
        //set bullet as a collision sensor
        setIsCollisionSensor(true);
        
        //I am of type
        setCollisionFilterCategory(kBullet);
        
        //I collide with type of
        setCollisionFilterMask(kEnemy|kPlayer);
        
        //set collision tag
        setCollidingTag("bullet");
        
        //set view direction
        U4DEngine::U4DVector3n defaultViewDirection(0.0,0.0,-1.0);
        setEntityForwardVector(defaultViewDirection);
        
        //set gravity to zero
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
        setGravity(zero);
        
        initMass(1.0);
        
        setState(idle);
        
        //send the info to the GPU
        loadRenderingInformation();
        
        return true;
    }
    
    return false;
}

void Bullet::update(double dt){
    
    if(getModelHasCollided()){
        
        pauseCollisionBehavior();
        
    }
    
    if(state==shooting){
        
        //move particle system
        U4DEngine::U4DVector3n pos=getAbsolutePosition();
        
        particleSystem->translateTo(pos);
        
        //apply force
        applyForce(80.0,dt);
        
    }
}

void Bullet::selfDestroy(){
    
    changeState(idle);
    
    U4DEngine::U4DEntity *parent=getParent();
    
    parent->removeChild(particleSystem);
    
    delete particleSystem;
    
    parent->removeChild(this);
    
    delete this;
    
}

void Bullet::setState(int uState){
    
    state=uState;
}

int Bullet::getState(){
 
    return state;
    
}

void Bullet::changeState(int uState){
    
    setState(uState);
    
    switch(uState){
            
        case idle:
            
            break;
            
        case shooting:
            
            createParticles();
            
            //set the self destroy scheduler
            setSchedulerToDestroy();
            
            break;
            
        default:
            break;
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
    
    //apply force
    addForce(force);
    
    //set initial velocity to zero
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    setVelocity(zero);
    
}

void Bullet::setForceDirection(U4DEngine::U4DVector3n &uForceDirection){
    
    forceDirection=uForceDirection;
}

void Bullet::createParticles(){
    
    //get parent of bullet
    U4DEngine::U4DEntity *parent=getParent();
    
    particleSystem=new U4DEngine::U4DParticleSystem();
    
    //load particle's attributes
    if(particleSystem->loadParticle("redBulletEmitter")){
        
        //particleSystem->setShader("vertexBulletShader","fragmentBulletShader");
        
        particleSystem->setEnableNoise(true);
        
        particleSystem->setNoiseDetail(4.0);
        
        //load the data into the GPU
        particleSystem->loadRenderingInformation();
        
        //add it to the game
        parent->addChild(particleSystem,-10);
        
        U4DEngine::U4DVector3n pos=getAbsolutePosition();
        
        particleSystem->translateTo(pos);
        
        particleSystem->play();
        
    }
    
}


void Bullet::setSchedulerToDestroy(){
    
    scheduler->scheduleClassWithMethodAndDelay(this,&Bullet::selfDestroy,timer,1.0,false);
    
}
