//
//  Player.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/7/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef Player_hpp
#define Player_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "UserCommonProtocols.h"
#include "U4DAnimation.h"
#include "U4DAnimationManager.h"
#include "U4DNavigation.h"
#include "Rifle.h"

class Player:public U4DEngine::U4DGameObject{
    
private:

    //Declare gun
    Rifle *rifle;
    
    U4DEngine::U4DGameObject *mapLevel;
    
    U4DEngine::U4DMatrix3n rampOrientation;

    U4DEngine::U4DVector3n navigationVelocity;
    
protected:
    
    //state of the character
    int state;
    
    //previous state of character
    int previousState;
    
    bool playerShooting;
    
    Player *hero;
    
    U4DEngine::U4DVector3n motionAccumulator;
    
    //force direction
    U4DEngine::U4DVector3n forceDirection;
    
    //walking animation pointer
    
    U4DEngine::U4DAnimation *idleAnimation;
    U4DEngine::U4DAnimation *patrolAnimation;
    U4DEngine::U4DAnimation *shootingAnimation;
    U4DEngine::U4DAnimation *deadAnimation;
    
    //Add an animation Manager
    U4DEngine::U4DAnimationManager *animationManager;
    
public:
    
    Player();
    
    ~Player();
    
    bool init(const char* uModelName);
    
    void update(double dt);
    
    void setState(int uState);
    
    int getState();
    
    int getPreviousState();
    
    void changeState(int uState);
    
    void applyForce(float uFinalVelocity, double dt);
    
    void applyVelocity(U4DEngine::U4DVector3n &uFinalVelocity, double dt);
    
    void setForceDirection(U4DEngine::U4DVector3n &uForceDirection);
    
    void setViewDirection(U4DEngine::U4DVector3n &uViewDirection);
    
    void setMap(U4DEngine::U4DGameObject *uMap);
    
    bool testMapIntersection();
        
    void testRampIntersection();
    
    void shoot();
    
    void setHero(Player *uHero);
    
    void setNavigationVelocity(U4DEngine::U4DVector3n &uNavigationVelocity);
    
};
#endif /* Player_hpp */
