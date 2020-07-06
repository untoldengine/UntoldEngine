//
//  Player.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/22/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef Player_hpp
#define Player_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "U4DAnimation.h"
#include "U4DAnimationManager.h"
#include "Weapon.h"
#include "U4DCallback.h"
#include "U4DTimer.h"
#include "U4DNavigation.h"

class Player:public U4DEngine::U4DGameObject {

private:
    
    //state of the character
    int state;
    
    //previous state of the character
    int previousState;
    
    //running animation
    U4DEngine::U4DAnimation *runningAnimation;
    
    //shooting animation
    U4DEngine::U4DAnimation *shootAnimation;
    
    //patrol animation
    U4DEngine::U4DAnimation *patrolAnimation;
    
    //patrol idle animation
    U4DEngine::U4DAnimation *patrolIdleAnimation;
    
    //dead animation
    U4DEngine::U4DAnimation *deadAnimation;
    
    //Animation Manager
    U4DEngine::U4DAnimationManager *animationManager;
    
    //force direction
    U4DEngine::U4DVector3n forceDirection;
    
    //pistol pointer
    Weapon *pistol;
    
    //map level
    U4DEngine::U4DGameObject *mapLevel;
    
    //scheduler for navigation
    U4DEngine::U4DCallback<Player> *navigationScheduler;
    
    //timer for navivation
    U4DEngine::U4DTimer *navigationTimer;
    
    //Navigation system
    U4DEngine::U4DNavigation *navigationSystem;
    
    //pointer to the leader of the game
    Player *leader;
    
    U4DEngine::U4DMatrix3n rampOrientation;
    
    //motion accumulator
    U4DEngine::U4DVector3n motionAccumulator;
    
public:
    
    Player();
    
    ~Player();
    
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
    
    void setViewDirection(U4DEngine::U4DVector3n &uViewDirection);
    
    void setWeapon(Weapon *uPistol);
    
    void setMap(U4DEngine::U4DGameObject *uMap);
    
    bool testMapIntersection();
    
    void testRampIntersection();
    
    void shoot();
    
    void computeNavigation();
    
    U4DEngine::U4DVector3n desiredNavigationVelocity();
    
    void setLeader(Player *uLeader);
    
    
    
};


#endif /* Player_hpp */
