//
//  Missile.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/22/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "Missile.h"
#include "U4DDigitalAssetLoader.h"


Missile::Missile():entityState(kNull){
    
}

Missile::~Missile(){
    
}

void Missile::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        enableCollisionBehavior();
        enableKineticsBehavior();
        initCoefficientOfRestitution(0.0);
        
        U4DEngine::U4DVector3n gravityForce(0.0,0.0,0.0);
        setGravity(gravityForce);
        
        scheduler=new U4DEngine::U4DCallback<Missile>;
        
        timer=new U4DEngine::U4DTimer(scheduler);
        
        //scheduler->scheduleClassWithMethodAndDelay(this, &Missile::selfDestroy, timer, 4.0,false);
        
        loadRenderingInformation();
    }
    
    
}

void Missile::update(double dt){
    
    if(getState()==kShoot){
        
        U4DEngine::U4DVector3n view=getViewInDirection();
        
        U4DEngine::U4DVector3n shootingForce(view.x*50.0,view.y*50.0,view.z*50.0);
        
        applyForce(shootingForce);
        
    }
    
}


void Missile::changeState(GameEntityState uState){
    
    setState(uState);
    
    switch (uState) {
            
        case kShoot:
            
            
            break;
            
        case kSelfDestroy:
            
            break;
            
        default:
            
            break;
    }
    
}

void Missile::setState(GameEntityState uState){
    
    entityState=uState;
}

GameEntityState Missile::getState(){
    
    return entityState;
}
