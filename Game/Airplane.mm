//
//  Airplane.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/10/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "Airplane.h"
#include "AirplaneRotor.h"
#include "AirplaneWing.h"
#include "Bullet.h"

Airplane::Airplane(){
    
    
}

Airplane::~Airplane(){
    
}

void Airplane::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        
        enableKineticsBehavior();
        enableCollisionBehavior();
        
        initCoefficientOfRestitution(0.0);
        
        initMass(10.0);
        
        U4DEngine::U4DVector3n gravityForce(0.0,0.0,0.0);
        setGravity(gravityForce);
        
        U4DEngine::U4DVector3n viewDirectionVector(0,0,1);
        
        setEntityForwardVector(viewDirectionVector);
        
        translateBy(3.0, 5.0, -20.0);
        
        U4DEngine::U4DVector3n view(0.0,0.6,6.0);
        
        viewInDirection(view);
        
        changeState(kFlying);
        
        //set rotor
        
        rotor=new AirplaneRotor();
        
        rotor->init("rotor", "airplanescript.u4d");
        
        rotor->setEntityForwardVector(viewDirectionVector);
        
        addChild(rotor);
        
        //set left wing
        
        leftWing=new AirplaneWing();
        
        leftWing->init("leftwing", "airplanescript.u4d");
        
        addChild(leftWing);
        
        //set right wing
        
        rightWing=new AirplaneWing();
        
        rightWing->init("rightwing", "airplanescript.u4d");
        
        addChild(rightWing);
        
        //set shooting timer
        
        scheduler=new U4DEngine::U4DCallback<Airplane>;
        
        shootingTimer=new U4DEngine::U4DTimer(scheduler);
        
        scheduler->scheduleClassWithMethodAndDelay(this, &Airplane::shoot, shootingTimer, 4.0,true);
        
        
    }
    
    
}

void Airplane::update(double dt){
    
    if (getState()==kFlying) {
        
        U4DEngine::U4DVector3n view=getViewInDirection();
        
        rotor->viewInDirection(view);
        
        U4DEngine::U4DVector3n flyingForce(view.x*10.0,0.0,view.z*10.0);
        
        applyForce(flyingForce);
        
    }else if (getState()==kShooting){
        
        if(world!=NULL){
            
            //create the bullet
            Bullet *bullet=new Bullet();
            
            bullet->init("bullet", "bulletscript.u4d");
            
            U4DEngine::U4DVector3n position=rotor->getAbsolutePosition();
            
            position.z+=1.5;
            
            U4DEngine::U4DVector3n aimVector=getViewInDirection();
            
            bullet->setShootingParameters(world, position, aimVector);
            
            bullet->shoot();
            
        }
        
        changeState(kFlying);
        
    }else if (getState()==kHit){
        
        scheduler->unScheduleTimer(shootingTimer);
        
        rightWing->enableKineticsBehavior();
        
        U4DEngine::U4DVector3n upForce(10.0,50.0,20.0);
        
        rightWing->applyForce(upForce);
        
        rotor->changeState(kNull);
        
        changeState(kNull);
        
    }
    
    
    if(getModelHasCollided()&&isDestroyed==false){
        
        changeState(kHit);
        
        isDestroyed=true;
        
    }
    
}
