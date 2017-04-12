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
#include "U4DAABB.h"

class U11PlayerStateInterface;
class U11PlayerStateManager;
class U11PlayerExtremity;
class U11Team;

class U11Player:public U4DEngine::U4DGameObject {
    
private:
    
    U11Team *team;
    
    U11PlayerStateManager *stateManager;
    
    bool joystickActive;
    
    U4DEngine::U4DVector3n joystickDirection;
    
    U11PlayerExtremity *rightFoot;
    
    U11PlayerExtremity *leftFoot;
    
    U11PlayerExtremity *activeExtremity;
    
    bool directionReversal;
    
    U4DEngine::U4DPoint3n supportPosition;
    
    U4DEngine::U4DAABB playerSpaceBox;
    
public:
    
    U11Player();
    
    ~U11Player();
    
    void init(const char* uModelName, const char* uBlenderFile);
    
    void update(double dt);
    
    U4DEngine::U4DAnimation *walkingAnimation;
    
    U4DEngine::U4DAnimation *rightFootSidePassAnimation;
    
    U4DEngine::U4DAnimation *leftFootSidePassAnimation;
    
    U4DEngine::U4DAnimation *runningAnimation;
    
    U4DEngine::U4DAnimation *forwardCarryAnimation;
    
    U4DEngine::U4DAnimation *sideCarryLeftAnimation;
    
    U4DEngine::U4DAnimation *sideCarryRightAnimation;
    
    U4DEngine::U4DAnimation *idleAnimation;
    
    U4DEngine::U4DAnimation *forwardHaltBallWithRightFootAnimation;
    
    U4DEngine::U4DAnimation *forwardHaltBallWithLeftFootAnimation;
    
    U4DEngine::U4DAnimation *backHaltBallWithRightFootAnimation;
    
    U4DEngine::U4DAnimation *backHaltBallWithLeftFootAnimation;
    
    U4DEngine::U4DAnimation *sideHaltBallWithRightFootAnimation;
    
    U4DEngine::U4DAnimation *sideHaltBallWithLeftFootAnimation;
    
    U4DEngine::U4DAnimation *rightFootForwardKickAnimation;
    
    U4DEngine::U4DAnimation *leftFootForwardKickAnimation;
    
    U4DEngine::U4DAnimation *reverseBallWithLeftFootAnimation;
    
    U4DEngine::U4DAnimation *reverseBallWithRightFootAnimation;
    
    U4DEngine::U4DAnimation *reverseRunningAnimation;
    
    U4DEngine::U4DAnimation *lateralRightRunAnimation;
    
    U4DEngine::U4DAnimation *lateralLeftRunAnimation;
    
    void changeState(U11PlayerStateInterface* uState);
    
    void applyForceToPlayer(float uVelocity, double dt);
    
    void applyForceToPlayerInDirection(float uVelocity, U4DEngine::U4DVector3n &uDirection, double dt);
    
    void setPlayerHeading(U4DEngine::U4DVector3n& uHeading);
    
    U4DEngine::U4DVector3n getPlayerHeading();
    
    U4DEngine::U4DAnimation *getRunningAnimation();
    
    U4DEngine::U4DAnimation *getForwardCarryAnimation();
    
    U4DEngine::U4DAnimation *getIdleAnimation();
    
    U4DEngine::U4DAnimation *getForwardHaltBallWithRightFootAnimation();
    
    U4DEngine::U4DAnimation *getForwardHaltBallWithLeftFootAnimation();
    
    U4DEngine::U4DAnimation *getBackHaltBallWithRightFootAnimation();
    
    U4DEngine::U4DAnimation *getBackHaltBallWithLeftFootAnimation();
    
    U4DEngine::U4DAnimation *getSideHaltBallWithRightFootAnimation();
    
    U4DEngine::U4DAnimation *getSideHaltBallWithLeftFootAnimation();
    
    U4DEngine::U4DAnimation *getRightFootSidePassAnimation();
    
    U4DEngine::U4DAnimation *getLeftFootSidePassAnimation();
    
    U4DEngine::U4DAnimation *getRightFootForwardKickAnimation();
    
    U4DEngine::U4DAnimation *getLeftFootForwardKickAnimation();
    
    U4DEngine::U4DAnimation *getReverseBallWithLeftFootAnimation();
    
    U4DEngine::U4DAnimation *getReverseBallWithRightFootAnimation();
    
    U4DEngine::U4DAnimation *getReverseRunningAnimation();
    
    U4DEngine::U4DAnimation *getLateralRightRunAnimation();
    
    U4DEngine::U4DAnimation *getLateralLeftRunAnimation();
    
    U4DEngine::U4DAnimation *getSideCarryLeftAnimation();
    
    U4DEngine::U4DAnimation *getSideCarryRightAnimation();
    
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
    
    void updatePlayerExtremity(U11PlayerExtremity *uPlayerExtremity);
    
    bool isRightFootCloserToBall();
    
    bool isBallOnRightSidePlane();
    
    bool isBallComingFromRightSidePlane();
    
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
    
    void subscribeTeam(U11Team *uTeam);
    
    U11Team *getTeam();
    
    U11Ball *getSoccerBall();
    
    void removeAllVelocities();
    
    bool hasReachedSupportPosition(U4DEngine::U4DPoint3n &uSupportPosition);
    
    void setSupportPosition(U4DEngine::U4DPoint3n &uSupportPosition);
    
    U4DEngine::U4DPoint3n &getSupportPosition();
    
    U11PlayerStateInterface *getCurrentState();
    
    U4DEngine::U4DAABB getUpdatedPlayerSpaceBox();
    
    void seekSupportPosition();
    
    bool isHeadingWithinRange();
    
    
};
#endif /* U11Player_hpp */
