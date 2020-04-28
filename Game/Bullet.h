//
//  Bullet.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/26/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef Bullet_hpp
#define Bullet_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "U4DCallback.h"
#include "U4DTimer.h"
#include "U4DParticleSystem.h"

class Bullet:public U4DEngine::U4DGameObject {

private:
    
    //declare the callback
    U4DEngine::U4DCallback<Bullet> *scheduler;
    
    //declare the timer
    U4DEngine::U4DTimer *timer;
    
    //force direction
    U4DEngine::U4DVector3n forceDirection;
    
    //state for bullet
    int state;
    
    //particle system
    U4DEngine::U4DParticleSystem *particleSystem;
    
public:
    
    Bullet();
    
    ~Bullet();
    
    bool init(const char* uModelName);
    
    void update(double dt);
    
    void selfDestroy();
    
    void setState(int uState);
    
    int getState();
    
    void changeState(int uState);
    
    void applyForce(float uFinalVelocity, double dt);
    
    void setForceDirection(U4DEngine::U4DVector3n &uForceDirection);
    
    void createParticles();
    
    void setSchedulerToDestroy();
    
    
};

#endif /* Bullet_hpp */
