//
//  Bullet.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/6/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "Bullet.h"

void Bullet::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        enableKineticsBehavior();
        
        U4DEngine::U4DVector3n gravityForce(0.0,0.0,0.0);
        setGravity(gravityForce);
    }
    
    
}

void Bullet::update(double dt){
    
    if (getState()==kShooting) {
        
        U4DEngine::U4DVector3n view=getViewInDirection();
        
        U4DEngine::U4DVector3n shootingForce(view.x*50.0,view.y,view.z*50.0);
        
        applyForce(shootingForce);
        
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
            
            
            break;
            
        default:
            
            break;
    }
    
    
    
}
