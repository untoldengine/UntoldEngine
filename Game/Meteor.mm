//
//  Meteor.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/3/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "Meteor.h"
#include "U4DRay.h"
#include "U4DRayCast.h"
#include "UserCommonProtocols.h"

Meteor::Meteor(){
    
}

Meteor::~Meteor(){
    
}

bool Meteor::init(const char* uModelName){
    
    if(loadModel(uModelName)){
        
        //disable shadows
        setEnableShadow(false);
        
        //enable kinetic behavior
        enableKineticsBehavior();
        
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

void Meteor::update(double dt){
    
    if(state==shooting){
        
        if(testMapIntersection()){
            
            changeState(asteroidCollided);
            
        }
        
        //move particle system
        U4DEngine::U4DVector3n pos=getAbsolutePosition();
        
        shootingParticles->translateTo(pos);
        
        //apply force
        applyForce(50.0,dt);
        
    }else if(state==idle || state==asteroidCollided){
        
        //remove all velocities from the character
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
        
        setVelocity(zero);
        setAngularVelocity(zero);
        
    }
    
}

void Meteor::setState(int uState){
    
    state=uState;
}

int Meteor::getState(){
    
    return state;
    
}

int Meteor::getPreviousState(){
    
    return previousState;
}

void Meteor::changeState(int uState){
    
    previousState=state;
    
    //set new state
    setState(uState);
    
    switch (uState) {
         
        case idle:
            //nothing happens
            
            break;
            
        case shooting:
        {
            U4DEngine::U4DVector3n finalPosition(-11.0,2.0,-1.0);
            
            forceDirection=finalPosition-getAbsolutePosition();
            forceDirection.normalize();
            
            createParticles();
        }
            break;
        
        case asteroidCollided:
            
            break;
            
        case asteroidExplosion:
            
            break;
            
        default:
            break;
    }
    
    
}

void Meteor::setForceDirection(U4DEngine::U4DVector3n &uForceDirection){
    
    forceDirection=uForceDirection;
    
}

void Meteor::applyForce(float uFinalVelocity, double dt){
    
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

void Meteor::applyVelocity(U4DEngine::U4DVector3n &uFinalVelocity, double dt){
    
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


void Meteor::setMap(U4DEngine::U4DGameObject *uMap){
    
    mapLevel=uMap;
}

bool Meteor::testMapIntersection(){
    
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

    if (rayCast.hit(ray, mapLevel, hitTriangle, intPoint, intTime)) {

        if(intTime<0.7){

            mapIntersection=true;
        }
    }
    
    return mapIntersection;
    
}

void Meteor::createParticles(){
    
    //get parent of bullet
    U4DEngine::U4DEntity *parent=getParent();
    
    shootingParticles=new U4DEngine::U4DParticleSystem();
    
    //load particle's attributes
    if(shootingParticles->loadParticle("asteroidparticles")){
        
        //particleSystem->setShader("vertexBulletShader","fragmentBulletShader");
        
        //shootingParticles->setEnableNoise(true);
        
        //shootingParticles->setNoiseDetail(4.0);
        
        //load the data into the GPU
        shootingParticles->loadRenderingInformation();
        
        //add it to the game
        parent->addChild(shootingParticles,-10);
        
        U4DEngine::U4DVector3n pos=getAbsolutePosition();
        
        shootingParticles->translateTo(pos);
        
        shootingParticles->play();
        
    }
    
}
