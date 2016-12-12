//
//  Bullet.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/6/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "Bullet.h"

Bullet::Bullet():shouldDestroy(false){
    
}

Bullet::~Bullet(){
    
    delete scheduler;
    delete timer;
}

void Bullet::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        enableKineticsBehavior();
        enableCollisionBehavior();
        //setBroadPhaseBoundingVolumeVisibility(true);
        
        U4DEngine::U4DVector3n gravityForce(0.0,0.0,0.0);
        setGravity(gravityForce);
        
        scheduler=new U4DEngine::U4DCallback<Bullet>;
        
        timer=new U4DEngine::U4DTimer(scheduler);
        
        scheduler->scheduleClassWithMethodAndDelay(this, &Bullet::selfDestroy, timer, 4.0,false);
        
    }
    
    
}

void Bullet::update(double dt){
    
    if (getState()==kShooting) {
        
        U4DEngine::U4DVector3n view=getViewInDirection();
        
        U4DEngine::U4DVector3n shootingForce(view.x*50.0,view.y*50.0,view.z*50.0);
        
        applyForce(shootingForce);
        
    }
    
    if(getModelHasCollided()){
        
        scheduler->unScheduleTimer(timer);
        selfDestroy();
        
    }
    
    
    
}

void Bullet::setState(GameEntityState uState){
    entityState=uState;
}

GameEntityState Bullet::getState(){
    return entityState;
}

void Bullet::changeState(GameEntityState uState){
    
    
    setState(uState);
    
    switch (uState) {
            
        case kShooting:
            
            break;
            
        case kCollided:
            
            resetGravity();
            
            break;
            
        default:
            
            break;
    }
    
}


void Bullet::setShootingParameters(U4DEngine::U4DWorld *uWorld, U4DEngine::U4DVector3n &uPosition, U4DEngine::U4DVector3n &uViewDirection){
    
    translateTo(uPosition);
    world=uWorld;
    setEntityForwardVector(uViewDirection);

}

void Bullet::shoot(){
    
    changeState(kShooting);
    
    world->addChild(this);
    
    loadRenderingInformation();
}

void Bullet::selfDestroy(){
    
    //remove from world
    world->removeChild(this);
    
    delete this;
}
