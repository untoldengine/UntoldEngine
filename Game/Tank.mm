//
//  Tank.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/6/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "Tank.h"
#include "TankGun.h"
#include "Bullet.h"

Tank::Tank(){
    
    scheduler=new U4DEngine::U4DCallback<Tank>;
    
    selfDestroyTimer=new U4DEngine::U4DTimer(scheduler);
    
    shootingTimer=new U4DEngine::U4DTimer(scheduler);
    
}

Tank::~Tank(){
    
    delete scheduler;
    delete selfDestroyTimer;
    delete shootingTimer;
}


void Tank::init(const char* uName, const char* uBlenderFile){
    
    
    if (loadModel(uName, uBlenderFile)) {
        
        enableCollisionBehavior();
        
        initMass(100.0);
        
        initCoefficientOfRestitution(0.0);
        
        U4DEngine::U4DVector3n viewDirectionVector(0,0,1);
        
        setEntityForwardVector(viewDirectionVector);
        
        translateTo(0.0, 0.5, -6.0);
        
        tankGun=new TankGun();
        
        tankGun->init("tankhead", "tankscript.u4d");
        
        tankGun->setEntityForwardVector(viewDirectionVector);
        
        addChild(tankGun);
        
        changeState(kAiming);
        
        scheduler->scheduleClassWithMethodAndDelay(this, &Tank::shoot, shootingTimer, 5.0,true);
    }
    
    
}

void Tank::update(double dt){
    
    if(getModelHasCollided()&&isDestroyed==false){
        
        changeState(kHit);
        
        isDestroyed=true;
    }
    
    if (getState()==kAiming) {
        
        tankGun->setJoystickData(joyStickData);
        tankGun->changeState(kAiming);
        
    }else if(getState()==kHit){
        
        scheduler->unScheduleTimer(shootingTimer);
        
        tankGun->changeState(kHit);
        
        changeState(kSelfDestroy);
    
    }else if(getState()==kShooting){
        
        if(world!=NULL){
            
            //create the bullet
            Bullet *bullet=new Bullet();
            
            bullet->init("bullet", "bulletscript.u4d");
            
            U4DEngine::U4DVector3n position=tankGun->getAbsolutePosition();
            position.z=-2.0;
            
            U4DEngine::U4DVector3n aimVector=getAimVector();
            
            bullet->setShootingParameters(world, position, aimVector);
            
            bullet->shoot();
            
        }
        
        changeState(kNull);
        
    }else if(getState()==kSelfDestroy){
        
        scheduler->scheduleClassWithMethodAndDelay(this, &Tank::selfDestroy, selfDestroyTimer, 2.0,false);
        
        changeState(kNull);
    }
    
}


U4DEngine::U4DVector3n Tank::getAimVector(){
    
    float zView =tankGun->getViewInDirection().z;
    float xView=tankGun->getViewInDirection().x;
    float yView=getViewInDirection().y;
    
    U4DEngine::U4DVector3n aimVector(xView,yView,zView);
    
    return aimVector;
    
}

void Tank::selfDestroy(){
    
    removeChild(tankGun);
    
    delete tankGun;
    
    delete this;
}
