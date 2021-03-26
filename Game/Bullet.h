//
//  Bullet.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/22/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef Bullet_hpp
#define Bullet_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "U4DCallback.h"
#include "U4DTimer.h"
#include "U4DParticleSystem.h"

class Bullet: public U4DEngine::U4DGameObject {

private:
    
    //declare the callback with the class name
    U4DEngine::U4DCallback<Bullet> *selfDestroyScheduler;
    
    //declare the timer
    U4DEngine::U4DTimer *selfDestroyTimer;
    
    //force direction
    U4DEngine::U4DVector3n forceDirection;
    
    //declare the particle system
    U4DEngine::U4DParticleSystem *particleSystem;
    
    int state;
    
public:
    
    Bullet();
    
    ~Bullet();
    
    bool init(const char* uModelName);
    
    void update(double dt);
    
    void applyForce(float uFinalVelocity, double dt);
    
    void setForceDirection(U4DEngine::U4DVector3n &uForceDirection);
        
    void setSchedulerToDestroy();
    
    void selfDestroy();
    
    void createParticle(const char* uParticleFile);
    
    void changeState(int uState);
    
    void setState(int uState);
    
    int getState();
    
    
};

#endif /* Bullet_hpp */
