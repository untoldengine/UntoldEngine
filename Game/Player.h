//
//  Player.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/28/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef Player_hpp
#define Player_hpp

#include <stdio.h>
#include "U4DModel.h"
#include "U4DDynamicAction.h"
#include "U4DAnimationManager.h"

#include "Foot.h"

#include "U4DArrive.h"

class PlayerStateInterface;
class PlayerStateManager;

class Player:public U4DEngine::U4DModel {
    
private:
    
    
    
    PlayerStateManager *stateManager;
    
    //motion accumulator
    U4DEngine::U4DVector3n motionAccumulator;
    
    //force direction
    
    
    U4DEngine::U4DVector3n forceMotionAccumulator;
    
    U4DEngine::U4DVector3n dribblingDirectionAccumulator;
    
public:
    
    bool shootBall;
    U4DEngine::U4DAnimation *runningAnimation;
    U4DEngine::U4DAnimation *idleAnimation;
    U4DEngine::U4DAnimation *shootingAnimation;
    U4DEngine::U4DAnimationManager *animationManager;
    
    U4DEngine::U4DDynamicAction *kineticAction;
    U4DEngine::U4DArrive arriveBehavior;
    U4DEngine::U4DVector3n dribblingDirection;
    
    Foot *foot;
    
    Player();
    
    ~Player();
    
    //init method. It loads all the rendering information among other things.
    bool init(const char* uModelName);
    
    void update(double dt);
    
    void changeState(PlayerStateInterface* uState);
    
    void setDribblingDirection(U4DEngine::U4DVector3n &uDribblingDirection);
    
    void applyForce(float uFinalVelocity, double dt);
    
    void applyVelocity(U4DEngine::U4DVector3n &uFinalVelocity, double dt);
    
    void setViewDirection(U4DEngine::U4DVector3n &uViewDirection);
    
    void setMoveDirection(U4DEngine::U4DVector3n &uMoveDirection);
    
    void setFoot(Foot *uFoot);
    
    void updateFootSpaceWithAnimation(U4DEngine::U4DAnimation *uAnimation);
    
    void setEnableShooting(bool uValue);
    
    PlayerStateInterface *getCurrentState();
    
};

#endif /* Player_hpp */
