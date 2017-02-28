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
class SoccerPlayerExtremity;

class SoccerPlayer:public U4DEngine::U4DGameObject {
    
private:
    
    SoccerBall *soccerBallEntity;
    
    SoccerPlayerStateManager *stateManager;
    
    bool buttonAPressed;
    
    bool buttonBPressed;
    
    bool joystickActive;
    
    U4DEngine::U4DVector3n joystickDirection;
    
    SoccerPlayerExtremity *rightFoot;
    
    SoccerPlayerExtremity *leftFoot;
    
    SoccerPlayerExtremity *activeExtremity;
    
    bool flagToPassBall;
    
    bool directionReversal;
    
public:
    
    SoccerPlayer();
    
    ~SoccerPlayer();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    U4DEngine::U4DAnimation *walkingAnimation;
    
    U4DEngine::U4DAnimation *rightFootSidePassAnimation;
    
    U4DEngine::U4DAnimation *leftFootSidePassAnimation;
    
    U4DEngine::U4DAnimation *runningAnimation;
    
    U4DEngine::U4DAnimation *forwardCarryAnimation;
    
    U4DEngine::U4DAnimation *sideCarryLeftAnimation;
    
    U4DEngine::U4DAnimation *sideCarryRightAnimation;
    
    U4DEngine::U4DAnimation *idleAnimation;
    
    U4DEngine::U4DAnimation *haltBallWithRightFootAnimation;
    
    U4DEngine::U4DAnimation *haltBallWithLeftFootAnimation;
    
    U4DEngine::U4DAnimation *rightFootForwardKickAnimation;
    
    U4DEngine::U4DAnimation *leftFootForwardKickAnimation;
    
    U4DEngine::U4DAnimation *reverseBallWithLeftFootAnimation;
    
    U4DEngine::U4DAnimation *reverseBallWithRightFootAnimation;
    
    void changeState(SoccerPlayerStateInterface* uState);
    
    void setBallEntity(SoccerBall *uSoccerBall);
    
    SoccerBall *getBallEntity();
    
    void applyForceToPlayer(float uVelocity, double dt);
    
    void setPlayerHeading(U4DEngine::U4DVector3n& uHeading);
    
    U4DEngine::U4DVector3n getPlayerHeading();
    
    U4DEngine::U4DAnimation *getRunningAnimation();
    
    U4DEngine::U4DAnimation *getForwardCarryAnimation();
    
    U4DEngine::U4DAnimation *getIdleAnimation();
    
    U4DEngine::U4DAnimation *getHaltBallWithRightFootAnimation();
    
    U4DEngine::U4DAnimation *getHaltBallWithLeftFootAnimation();
    
    U4DEngine::U4DAnimation *getRightFootSidePassAnimation();
    
    U4DEngine::U4DAnimation *getLeftFootSidePassAnimation();
    
    U4DEngine::U4DAnimation *getRightFootForwardKickAnimation();
    
    U4DEngine::U4DAnimation *getLeftFootForwardKickAnimation();
    
    U4DEngine::U4DAnimation *getReverseBallWithLeftFootAnimation();
    
    U4DEngine::U4DAnimation *getReverseBallWithRightFootAnimation();
    
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
    
    void kickBallToAir(float uVelocity, U4DEngine::U4DVector3n uDirection, double dt);
    
    void setJoystickDirection(U4DEngine::U4DVector3n uJoystickDirection);
    
    U4DEngine::U4DVector3n getJoystickDirection();
    
    float distanceToBall();
    
    void setFlagToPassBall(bool uValue);
    
    bool getFlagToPassBall();
    
    void updatePlayerExtremity(SoccerPlayerExtremity *uPlayerExtremity);
    
    bool isRightFootCloserToBall();
    
    bool isBallOnRightSidePlane();
    
    void setActiveExtremity(SoccerPlayerExtremity *uActiveExtremity);
    
    SoccerPlayerExtremity *getActiveExtremity();
    
    SoccerPlayerExtremity *getRightFoot();
    
    SoccerPlayerExtremity *getLeftFoot();
    
    bool getActiveExtremityCollidedWithBall();
    
    bool getRightFootCollidedWithBall();
    
    bool getLeftFootCollidedWithBall();
    
    void decelerateBall(float uScale, double dt);
    
    void decelerate(float uScale, double dt);
    
    void setDirectionReversal(bool uValue);
    
    bool getDirectionReversal();
    
    
};
#endif /* SoccerPlayer_hpp */
