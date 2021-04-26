//
//  UserCommonProtocols.h
//  UntoldEngine
//
//  Created by Harold Serrano on 10/16/16.
//  Copyright © 2016 Untold Engine Studios. All rights reserved.
//

#ifndef UserCommonProtocols_h
#define UserCommonProtocols_h

#include "U4DVector3n.h"
#include "U4DVector2n.h"
#include <string>

class Player;
class Team;

typedef struct{
    
    U4DEngine::U4DVector3n direction;
    U4DEngine::U4DVector3n mousePosition;
    U4DEngine::U4DVector3n previousMousePosition;
    U4DEngine::U4DVector2n mouseDeltaPosition;
    bool changedDirection;
    
}JoystickMessageData;



enum{
    
    selectingKit,
    selectingOptionsInMenu,
    
}MENUSTATE;

enum{
    idle,
    stopped,
    rolling,
    kicked,
    decelerating,
    scored,
    
}BALLSTATE;

typedef struct{
    
    Player *senderPlayer;
    Player *receiverPlayer;
    Team *receiverTeam;
    Team *team;
    int msg;
    void *extraInfo;
    
}Message;



enum{
    
    msgChaseBall,
    msgInterceptBall,
    msgSupport,
    msgMark,
    msgFormation,
    msgIdle,
    msgWander,
    msgGoHome,
    
}PlayerMessage;

enum{

    msgTeamStart,
    msgTeamDefend,
    msgTeamAttack,
    msgTeamGoHome,
    msgTeamIdle
    
}TeamMessage;

enum MouseMovementDirection{
    forwardDir,
    backwardDir,
    rightDir,
    leftDir,
    noDir,
};

typedef enum{
    
    kPlayer=0x0002,
    kBall=0x0004,
    kFoot=0x0008,
    kOppositePlayer=0x000A,
    kGoalSensor=0x0020,
    
}GameEntityCollision;

//ORIGINAL VALUES
//const float dribbleBallSpeed=30.0;
//const float tapBallSpeed=25.0;
//const float passBallSpeed=45.0;
//const float shootBallSpeed=150.0;
//const float runSpeed=15.0;
//const float arriveMaxSpeed=25.0;
//const float arriveStopRadius=0.5;
//const float arriveSlowRadius=1.0;
//const float pursuitMaxSpeed=30.0;
//const float avoidanceMaxSpeed=35.0;
//const float arriveJogMaxSpeed=15.0;
//const float arriveJogStopRadius=0.25;
//const float arriveJogSlowRadius=0.3;
//const float halfwayBallOffset=0.5;  //this is the distance between the player's crotch and his right foot.
//const float neighborPlayerSeparationDistance=15.0;
//const float neighborPlayerAlignmentDistance=40.0;
//const float neighborPlayerCohesionDistance=40.0;
//const float slidingTackleKick=45.0;
//const float markArrivingMaxSpeed=20.0;
//const float markArriveStopRadius=5.0;
//const float markArriveSlowRadius=7.0;
//const float markAvoidanceMaxSpeed=20.0;
//const float markAvoidanceTimeParameter=10.0;
//const float markPursuitMaxSpeed=40.0/scaleValue;

const float scaleValue=1.0;
const float dribbleBallSpeed=30.0/scaleValue;
const float tapBallSpeed=25.0/scaleValue;
const float passBallSpeed=45.0/scaleValue;
const float shootBallSpeed=120.0/scaleValue;
const float runSpeed=30.0/scaleValue;
const float arriveMaxSpeed=35.0/scaleValue;
const float arriveStopRadius=0.75/scaleValue;
const float arriveSlowRadius=1.0/scaleValue;
const float pursuitMaxSpeed=25.0/scaleValue;
const float avoidanceMaxSpeed=35.0/scaleValue;
const float arriveJogMaxSpeed=15.0/scaleValue;
const float arriveJogStopRadius=0.25/scaleValue;
const float arriveJogSlowRadius=0.3/scaleValue;
const float slidingTackleKick=40.0;
const float halfwayBallOffset=0.2;  //this is the distance between the player's crotch and his right foot.
const float neighborPlayerSeparationDistance=14.0; //5
const float neighborPlayerAlignmentDistance=30.0; //20
const float neighborPlayerCohesionDistance=30.0; //20
const float markArrivingMaxSpeed=40.0/scaleValue;
const float markArriveStopRadius=2.0/scaleValue;
const float markArriveSlowRadius=3.0/scaleValue;
const float markAvoidanceMaxSpeed=40.0/scaleValue;
const float markAvoidanceTimeParameter=20.0/scaleValue;
const float markPursuitMaxSpeed=40.0/scaleValue;


#endif /* UserCommonProtocols_h */
