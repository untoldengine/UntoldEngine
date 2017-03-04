//
//  U11Player.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/30/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11Player_hpp
#define U11Player_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "UserCommonProtocols.h"
#include "U11Ball.h"

class U11PlayerStateInterface;
class U11PlayerStateManager;
class U11PlayerExtremity;

class U11Player:public U4DEngine::U4DGameObject {
    
private:
    
    U11Ball *soccerBallEntity;
    
    U11PlayerStateManager *stateManager;
    
    bool buttonAPressed;
    
    bool buttonBPressed;
    
    bool joystickActive;
    
    U4DEngine::U4DVector3n joystickDirection;
    
    U11PlayerExtremity *rightFoot;
    
    U11PlayerExtremity *leftFoot;
    
    U11PlayerExtremity *activeExtremity;
    
    bool flagToPassBall;
    
    bool directionReversal;
    
public:
    
    U11Player();
    
    ~U11Player();
    
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
    
    void changeState(U11PlayerStateInterface* uState);
    
    void setBallEntity(U11Ball *uU11Ball);
    
    U11Ball *getBallEntity();
    
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
    
    void seekBall();
    
    void interseptBall();
    
    bool hasReachedTheBall();
    
    void removeKineticForces();
    
    void kickBallToGround(float uVelocity, U4DEngine::U4DVector3n uDirection, double dt);
    
    void kickBallToAir(float uVelocity, U4DEngine::U4DVector3n uDirection, double dt);
    
    void setJoystickDirection(U4DEngine::U4DVector3n uJoystickDirection);
    
    U4DEngine::U4DVector3n getJoystickDirection();
    
    float distanceToBall();
    
    void setFlagToPassBall(bool uValue);
    
    bool getFlagToPassBall();
    
    void updatePlayerExtremity(U11PlayerExtremity *uPlayerExtremity);
    
    bool isRightFootCloserToBall();
    
    bool isBallOnRightSidePlane();
    
    void setActiveExtremity(U11PlayerExtremity *uActiveExtremity);
    
    U11PlayerExtremity *getActiveExtremity();
    
    U11PlayerExtremity *getRightFoot();
    
    U11PlayerExtremity *getLeftFoot();
    
    bool getActiveExtremityCollidedWithBall();
    
    bool getRightFootCollidedWithBall();
    
    bool getLeftFootCollidedWithBall();
    
    void decelerateBall(float uScale, double dt);
    
    void decelerate(float uScale, double dt);
    
    void setDirectionReversal(bool uValue);
    
    bool getDirectionReversal();
    
    bool handleMessage(Message &uMsg);
    
    
};
#endif /* U11Player_hpp */
