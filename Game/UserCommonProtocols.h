//
//  UserCommonProtocols.h
//  UntoldEngine
//
//  Created by Harold Serrano on 10/16/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef UserCommonProtocols_h
#define UserCommonProtocols_h

#include "U4DVector3n.h"

class U11Player;
class U11Team;
class U11TriangleEntity;

typedef enum{

    kU11Ball=1,
    kU11Field=2,
    kU11Player=3,
    kSoccerPostSensor=4,
    kSoccerGoalSensor=5,
    kU11PlayerExtremity=6,
    kNegativeGroupIndex=-10,
    kPositiveGroupIndex=10,
    kPlayerExtremitiesGroupIndex=-6,
    kZeroGroupIndex=0,

}GameEntityCollision;

typedef struct{
    
    U11Player *senderPlayer;
    U11Player *receiverPlayer;
    U11Team *receiverTeam;
    int msg;
    void* extraInfo;
    
}Message;

typedef struct{
    
    U4DEngine::U4DVector3n direction;
    bool changedDirection;
    
}JoystickMessageData;

enum{
    
    //attack
    msgReceiveBall,
    msgRunToAttackFormation,
    msgSupportPlayer,
    msgPassToMe,
    msgRunToSupport,
    msgDribble,
    msgPassBall,
    
    //defend
    msgRunToDefend,
    msgRunToDefendingFormation,
    msgRunToSteal,
    msgIntercept,
    msgApproachOpponent,
    msgInterceptionFailed,
    //idle
    msgIdle,
    
    //input
    msgButtonAPressed,
    msgButtonBPressed,
    msgJoystickActive,
    msgJoystickNotActive,
    
    msgBallRelinquished,
    msgBallPassed,
    msgBallInPossession,
    
    
    msgChaseBall,
    
}MessageEnum;

typedef struct{
    
    U11TriangleEntity *triangleEntity;
    int playersInsideEntity;
    int playersInSightToGoal;
    float distanceToGoal;
    
}TriangleNodeEntity;


enum{
    
    actionButtonA,
    actionButtonB,
    actionJoystick,
    
}TouchInputType;


enum{
    buttonPressed,
    buttonReleased,
    joystickActive,
    joystickInactive
    
}TouchInputData;

typedef struct{
    
    int touchInputType;
    int touchInputData;
    U4DEngine::U4DVector3n joystickDirection;
    bool joystickChangeDirection;
    
}TouchInputMessage;

const float fieldWidth=1000.0;
const float fieldLength=1000.0;
const float playingFieldLength=200.0;
const float playingFieldWidth=135.0;

const float chasingSpeed=13.0;

const float minDribblingSpeed=7.0;

const float ballRollingSpeed=14.5;

const float offsetHandedness=0.38;



const float markingSpeed=20.0;



const float ballTapSpeed=50.0;
const float ballGroundShotSpeed=70.0;
const float ballAirShotSpeed=80.0;
const float ballReverseRolling=15.0;
const float ballDeceleration=0.5;
const float ballMaxSpeed=4.0;

const float ballControlMaximumDistance=0.8;

const float reverseBallMaximumDistance=0.5;


const float reverseRunningSpeed=20.0;
const float lateralRunningSpeed=20.0;

const float supportMinimumDistanceToPlayer=5.0;
const float supportMaximumDistanceToPlayer=15.0;

const float dribblingMinimumDistanceToPlayer=15.0;
const int   maximumSupportPoints=36;
const int   maximumDribblingSpace=36;
const int   supportPointsSeparation=10;
const int   dribblingSpaceSeparation=10;
const float ballPassSegmentDirection=10.0;
const float withinSupportDistance=2.5;
const float withinDefenseDistance=2.5;
const float withinFormationDistance=2.5;
const float stealingDistanceToBall=1.0;
const float markingDistanceToBall=5.0;
const float defenseSpace=0.15;
const float formationDefenseSpace=0.5;
const float formationSpaceBoundaryLength=420.0;
const float formationSpaceBoundaryWidth=70.0;
const float minimumInterceptionDistance=30.0;
const float threateningDistanceToPlayer=20.0;
const float playerPersonalArea=5.0;
const float triangleEntityDistance=20.0;

//maximum
const float maximumInterceptionSpeed=15.0;
const float maximumBallSpeed=20.0;


#endif /* UserCommonProtocols_h */
