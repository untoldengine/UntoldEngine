//
//  Meteor.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/3/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef Asteroid_hpp
#define Asteroid_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "U4DParticleSystem.h"

class Meteor:public U4DEngine::U4DGameObject {

private:
    
    //state of the character
    int state;
    
    //previous state of the character
    int previousState;
    
    //force direction
    U4DEngine::U4DVector3n forceDirection;
    
    //map level
    U4DEngine::U4DGameObject *mapLevel;
    
    //particle system
    U4DEngine::U4DParticleSystem *shootingParticles;
    
    U4DEngine::U4DParticleSystem *explosionParticles;
    
public:
    
    Meteor();
    
    ~Meteor();
    
    //init method. It loads all the rendering information among other things.
    bool init(const char* uModelName);
    
    void update(double dt);
    
    void setState(int uState);
    
    int getState();
    
    int getPreviousState();
    
    void changeState(int uState);
    
    void setForceDirection(U4DEngine::U4DVector3n &uForceDirection);
    
    void applyForce(float uFinalVelocity, double dt);
    
    void applyVelocity(U4DEngine::U4DVector3n &uFinalVelocity, double dt);
    
    void setMap(U4DEngine::U4DGameObject *uMap);
    
    bool testMapIntersection();
    
    void createParticles();
    
};

#endif /* Asteroid_hpp */
