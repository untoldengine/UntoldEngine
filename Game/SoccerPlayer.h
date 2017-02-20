//
//  SoccerPlayer.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/30/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerPlayer_hpp
#define SoccerPlayer_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "UserCommonProtocols.h"
#include "SoccerBall.h"

class SoccerPlayerStateInterface;
class SoccerPlayerStateManager;

class SoccerPlayer:public U4DEngine::U4DGameObject {
    
private:
    
    SoccerBall *soccerBallEntity;
    
    SoccerPlayerStateManager *stateManager;
    
    bool buttonAPressed;
    
    bool buttonBPressed;
    
    bool joystickActive;
    
public:
    
    SoccerPlayer();
    
    ~SoccerPlayer();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    U4DEngine::U4DAnimation *forwardKickAnimation;
    
    U4DEngine::U4DAnimation *walkingAnimation;
    
    U4DEngine::U4DAnimation *sidePassAnimation;
    
    U4DEngine::U4DAnimation *runningAnimation;
    
    U4DEngine::U4DAnimation *forwardCarryAnimation;
    
    U4DEngine::U4DAnimation *sideCarryLeftAnimation;
    
    U4DEngine::U4DAnimation *sideCarryRightAnimation;
    
    U4DEngine::U4DAnimation *idleAnimation;
    
    U4DEngine::U4DAnimation *takingBallControlAnimation;
    
    void changeState(SoccerPlayerStateInterface* uState);
    
    void setBallEntity(SoccerBall *uSoccerBall);
    
    void applyForceToPlayer(float uVelocity, double dt);
    
    void setPlayerHeading(U4DEngine::U4DVector3n& uHeading);
    
    U4DEngine::U4DAnimation *getRunningAnimation();
    
    U4DEngine::U4DAnimation *getSidePassAnimation();
    
    U4DEngine::U4DAnimation *getForwardCarryAnimation();
    
    U4DEngine::U4DAnimation *getIdleAnimation();
    
    U4DEngine::U4DAnimation *getTakingBallControlAnimation();
    
    void receiveTouchUpdate(bool uButtonAPressed, bool uButtonBPressed, bool uJoystickActive);
    
    void setButtonAPressed(bool uValue);
    
    void setButtonBPressed(bool uValue);
    
    bool getButtonAPressed();
    
    bool getButtonBPressed();
    
    void setJoystickActive(bool uValue);
    
    bool getJoystickActive();
    
    void trackBall();
    
    bool hasReachedTheBall();
    
    void removeKineticForces();
    
    void kickBallToGround(float uVelocity, U4DEngine::U4DVector3n uDirection, double dt);
    
};
#endif /* SoccerPlayer_hpp */
