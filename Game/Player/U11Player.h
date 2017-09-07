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
class U11FormationEntity;
class U11PlayerSpace;

class U11Player:public U4DEngine::U4DGameObject {
    
private:
    
    U11Team *team;
    
    U11Player *threateningPlayer;
    
    U11PlayerStateManager *stateManager;
    
    bool joystickActive;
    
    U4DEngine::U4DVector3n joystickDirection;
    
    U11PlayerExtremity *rightFoot;
    
    U11PlayerExtremity *leftFoot;
    
    U11PlayerExtremity *activeExtremity;
    
    U11PlayerSpace *playerSpace;
    
    bool directionReversal;
    
    U4DEngine::U4DPoint3n supportPosition;
    
    U4DEngine::U4DPoint3n defendingPosition;
    
    bool missedTheBall;
    
    int ballKickSpeed;
    
    U4DEngine::U4DVector3n ballKickDirection;
    
    U11FormationEntity *formationEntity;
    
    U4DEngine::U4DPoint3n formationPosition;
    
    U4DEngine::U4DAnimation *walkingAnimation;
    
    U4DEngine::U4DAnimation *runningAnimation;
    
    U4DEngine::U4DAnimation *idleAnimation;
    
    //passing
    U4DEngine::U4DAnimation *rightPassAnimation;
    
    U4DEngine::U4DAnimation *leftPassAnimation;
    
    
    //dribble
    U4DEngine::U4DAnimation *rightDribbleAnimation;
    
    U4DEngine::U4DAnimation *leftDribbleAnimation;
    
    
    //halt
    U4DEngine::U4DAnimation *rightSoleHaltAnimation;
    
    U4DEngine::U4DAnimation *leftSoleHaltAnimation;
    
    U4DEngine::U4DAnimation *rightInsideHaltAnimation;
    
    U4DEngine::U4DAnimation *leftInsideHaltAnimation;
    
    U4DEngine::U4DAnimation *rightSideHaltAnimation;
    
    U4DEngine::U4DAnimation *leftSideHaltAnimation;
    
    //kick
    
    U4DEngine::U4DAnimation *rightShotAnimation;
    
    U4DEngine::U4DAnimation *leftShotAnimation;
    
    //change direction
    
    U4DEngine::U4DAnimation *leftReverseKickAnimation;
    
    U4DEngine::U4DAnimation *rightReverseKickAnimation;
    
    //back peddal
    
    U4DEngine::U4DAnimation *backPeddalAnimation;
    
    //lateral rum
    
    U4DEngine::U4DAnimation *lateralRightRunAnimation;
    
    U4DEngine::U4DAnimation *lateralLeftRunAnimation;
    
    //defense-mark
    
    U4DEngine::U4DAnimation *markingAnimation;
    
    //defense-stealing
    
    U4DEngine::U4DAnimation *stealingAnimation;
    
    bool processedForTriangleNode;
    
    float playerDribblingSpeed;
    
    int rightHanded;
    
public:
    
    U11Player();
    
    ~U11Player();
    
    void init(const char* uModelName, const char* uBlenderFile);
    
    void update(double dt);
    
    void changeState(U11PlayerStateInterface* uState);
    
    void applyForceToPlayer(float uVelocity, double dt);
    
    void applyForceToPlayerInDirection(float uVelocity, U4DEngine::U4DVector3n &uDirection, double dt);
    
    void setPlayerHeading(U4DEngine::U4DVector3n& uHeading);
    
    U4DEngine::U4DVector3n getPlayerHeading();
    
    U4DEngine::U4DAnimation *getRunningAnimation();
    
    U4DEngine::U4DAnimation *getIdleAnimation();
    
    U4DEngine::U4DAnimation *getRightPassAnimation();
    
    U4DEngine::U4DAnimation *getLeftPassAnimation();
    
    U4DEngine::U4DAnimation *getRightDribbleAnimation();
    
    U4DEngine::U4DAnimation *getLeftDribbleAnimation();
    
    
    
    
    U4DEngine::U4DAnimation *getRightSoleHaltAnimation();
    
    U4DEngine::U4DAnimation *getLeftSoleHaltAnimation();
    
    U4DEngine::U4DAnimation *getRightInsideHaltAnimation();
    
    U4DEngine::U4DAnimation *getLeftInsideHaltAnimation();
    
    U4DEngine::U4DAnimation *getRightSideHaltAnimation();
    
    U4DEngine::U4DAnimation *getLeftSideHaltAnimation();
    
    
    
    U4DEngine::U4DAnimation *getRightShotAnimation();
    
    U4DEngine::U4DAnimation *getLeftShotAnimation();
    
    
    
    U4DEngine::U4DAnimation *getRightReverseKickAnimation();
    
    U4DEngine::U4DAnimation *getLeftReverseKickAnimation();
    
    
    
    U4DEngine::U4DAnimation *getBackPeddalAnimation();
    
    
    
    U4DEngine::U4DAnimation *getLateralRightRunAnimation();
    
    U4DEngine::U4DAnimation *getLateralLeftRunAnimation();
    
    
    U4DEngine::U4DAnimation *getRightCarryAnimation();
    
    U4DEngine::U4DAnimation *getLeftCarryAnimation();
    
    U4DEngine::U4DAnimation *getMarkingAnimation();
    
    U4DEngine::U4DAnimation *getStealingAnimation();
    
    
    
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
    
    bool hasReachedPosition(U4DEngine::U4DPoint3n &uPosition, float uWithinDistance);
    
    void setSupportPosition(U4DEngine::U4DPoint3n &uSupportPosition);
    
    U4DEngine::U4DPoint3n &getSupportPosition();
    
    void setDefendingPosition(U4DEngine::U4DPoint3n &uDefendingPosition);
    
    U4DEngine::U4DPoint3n &getDefendingPosition();
    
    U11PlayerStateInterface *getCurrentState();
    
    U4DEngine::U4DAABB getUpdatedPlayerSpaceBox();
    
    void seekPosition(U4DEngine::U4DPoint3n &uPosition);
    
    bool isHeadingWithinRange();
    
    void setMissedTheBall(bool uValue);
    
    bool getMissedTheBall();
    
    void setFormationEntity(U11FormationEntity *uFormationEntity);
    
    U11FormationEntity *getFormationEntity();
    
    void setFormationPosition(U4DEngine::U4DPoint3n &uFormationPosition);
    
    U4DEngine::U4DPoint3n &getFormationPosition();
    
    void pauseExtremityCollision();
    
    void resumeExtremityCollision();
    
    void setBallKickSpeed(float uBallKickSpeed);
    
    float getBallKickSpeed();
    
    void setBallKickDirection(U4DEngine::U4DVector3n &uDirection);
    
    U4DEngine::U4DVector3n getBallKickDirection();
    
    void setThreateningPlayer(U11Player* uThreateningPlayer);
    
    U11Player* getThreateningPlayer();
    
    U4DEngine::U4DVector3n getCurrentPosition();
    
    void setProcessedForTriangleNode(bool uValue);
    
    bool getProcessedForTriangleNode();
    
    void computePlayerDribblingSpeed();
    
    float getPlayerDribblingSpeed();

};
#endif /* U11Player_hpp */
