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
#include "U4DCallback.h"
#include "U4DTimer.h"
#include "U4DArrive.h"
#include "U4DAvoidance.h"
#include "U4DFlock.h"
#include "U4DPursuit.h"
#include "U4DFlock.h"
#include "U4DWander.h"

#include "UserCommonProtocols.h"

class PlayerStateInterface;
class PlayerStateManager;

class Foot;
class Team;

class Player:public U4DEngine::U4DGameObject {

private:

    //state manager
    PlayerStateManager *stateManager;
    
    //running animation
    U4DEngine::U4DAnimation *runningAnimation;
    
    //patrol idle animation
    U4DEngine::U4DAnimation *idleAnimation;
    
    //dribbling animation
    U4DEngine::U4DAnimation *dribblingAnimation;
    
    //halt animation
    U4DEngine::U4DAnimation *haltAnimation;
    
    //passing animation
    U4DEngine::U4DAnimation *passingAnimation;
    
    //shooting animation
    U4DEngine::U4DAnimation *shootingAnimation;
    
    //stand tackle animation
    U4DEngine::U4DAnimation *standTackleAnimation;
    
    //stand tackle animation
    U4DEngine::U4DAnimation *slidingTackleAnimation;
    
    //contain animation
    U4DEngine::U4DAnimation *containAnimation;
    
    //tap animation
    U4DEngine::U4DAnimation *tapAnimation;
    
    //jogging animation
    U4DEngine::U4DAnimation *joggingAnimation;
    
    //Animation Manager
    U4DEngine::U4DAnimationManager *animationManager;
    
    
    
    
    //motion accumulator
    U4DEngine::U4DVector3n motionAccumulator;
    
    U4DEngine::U4DVector3n forceMotionAccumulator;
    
    
    //Team player belongs to
    Team *team;
    
    int playerIndex;
    
    //Marking-defense position
    U4DEngine::U4DVector3n markingPosition;

public:
    
    //force direction
    U4DEngine::U4DVector3n forceDirection;
    
    Player();
    
    ~Player();
    
    bool dribbleBall;
    
    bool passBall;
    
    bool shootBall;
    
    bool haltBall;
    
    bool wander;
    
    bool standTackleOpponent;
    
    U4DEngine::U4DArrive arriveBehavior;
    
    U4DEngine::U4DPursuit pursuitBehavior;
    
    U4DEngine::U4DAvoidance avoidanceBehavior;
    
    U4DEngine::U4DFlock flockBehavior;
    
    U4DEngine::U4DWander wanderBehavior;
    
    //right foot
    Foot *rightFoot;
    
    //dribbling direction
    U4DEngine::U4DVector3n dribblingDirection;
    
    //init method. It loads all the rendering information among other things.
    bool init(const char* uModelName);
    
    void update(double dt);
    

    PlayerStateInterface *getCurrentState();
    
    PlayerStateInterface *getPreviousState();
    
    void changeState(PlayerStateInterface *uState);
    
    void setMoveDirection(U4DEngine::U4DVector3n &uMoveDirection);
    
    void setForceDirection(U4DEngine::U4DVector3n &uForceDirection);
    
    void setDribblingDirection(U4DEngine::U4DVector3n &uDribblingDirection);
    
    void applyForce(float uFinalVelocity, double dt);
    
    void applyVelocity(U4DEngine::U4DVector3n &uFinalVelocity, double dt);
    
    void setViewDirection(U4DEngine::U4DVector3n &uViewDirection);
    
    void setFoot(Foot *uRightFoot);
    
    void setEnableDribbling(bool uValue);
    
    void setEnablePassing(bool uValue);
    
    void setEnableShooting(bool uValue);
    
    void setEnableStandTackle(bool uValue);
    
    void setEnableHalt(bool uValue);
    
    U4DEngine::U4DVector3n getBallPositionOffset();
    
    void updateFootSpaceWithAnimation(U4DEngine::U4DAnimation *uAnimation);
    
    void addToTeam(Team *uTeam);
    
    Team *getTeam();
    
    U4DEngine::U4DAnimationManager *getAnimationManager();
    
    U4DEngine::U4DAnimation *getAnimationToPlay();
    
    void handleMessage(Message &uMsg);
    
    void setPlayerIndex(int uIndex);
    
    int getPlayerIndex();
    
    U4DEngine::U4DVector3n getMarkingPosition();
    
    
};


#endif /* Player_hpp */
