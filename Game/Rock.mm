//
//  Rock.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/4/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "Rock.h"
#include "U4DDigitalAssetLoader.h"

Rock::Rock():isDestroyed(false){
    
    scheduler=new U4DEngine::U4DCallback<Rock>;
    timer=new U4DEngine::U4DTimer(scheduler);
}

Rock::~Rock(){
    
}

void Rock::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        enableCollisionBehavior();
        initCoefficientOfRestitution(0.0);
        enableKineticsBehavior();
        
        U4DEngine::U4DVector3n gravity(0.0,0.0,0.0);
        setGravity(gravity);
        
        loadRenderingInformation();
    }
    

}

void Rock::update(double dt){
    
    if (getModelHasCollided()&&isDestroyed==false) {
        
        changeState(kHit);
        
        isDestroyed=true;
    }
    
    if (getState()==kHit) {
        
        //set up timer
        //scheduler->scheduleClassWithMethodAndDelay(this, &Rock::selfDestroy, timer, 2.0, false);
        selfDestroy();
        changeState(kNull);
        
    }
    
    
    
}

void Rock::changeState(GameEntityState uState){
    
    setState(uState);
    
    switch (uState) {
            
        case kSelfDestroy:
            
            break;
            
        case kHit:
            
            break;
            
        default:
            
            break;
    }
    
}

void Rock::setState(GameEntityState uState){
    
    entityState=uState;
}

GameEntityState Rock::getState(){
    
    return entityState;
}

void Rock::selfDestroy(){
    
    U4DEngine::U4DEntity *world=getRootParent();
    
    world->removeChild(this);
    
    delete this;
    
}
