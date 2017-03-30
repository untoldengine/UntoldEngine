//
//  UserCommonProtocols.h
//  UntoldEngine
//
//  Created by Harold Serrano on 10/16/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef UserCommonProtocols_h
#define UserCommonProtocols_h

class U11Player;

typedef enum{

    kU11Ball=1,
    kU11Field=2,
    kU11Player=3,
    kSoccerPostSensor=4,
    kSoccerGoalSensor=5,
    kNegativeGroupIndex=-10,
    kPositiveGroupIndex=10,
    kPlayerExtremitiesGroupIndex=-6,
    kZeroGroupIndex=0,

}GameEntityCollision;

typedef struct{
    
    U11Player *senderPlayer;
    U11Player *receiverPlayer;
    int msg;
    
}Message;

enum{
    
    msgReceiveBall,
    msgButtonAPressed,
    msgButtonBPressed,
    msgSupportPlayer,
    msgPassToMe
    
}MessageEnum;

const float fieldWidth=256.0;
const float fieldLength=256.0;

const float chasingSpeed=40.0;
const float dribblingSpeed=30.0;
const float ballRollingSpeed=35.0;
const float ballPassingSpeed=50.0;
const float ballGroundShotSpeed=70.0;
const float ballAirShotSpeed=30.0;
const float ballReverseRolling=35.0;
const float ballDeceleration=0.5;
const float ballMaxSpeed=8.0;
const float maximumInterceptionSpeed=80.0;
const float ballControlMaximumDistance=6.0;
const float reverseBallMaximumDistance=2.0;
const float reverseRunningSpeed=20.0;
const float lateralRunningSpeed=20.0;
const float supportMinimumDistanceToPlayer=25.0;
const float supportMaximumDistanceToPlayer=50.0;
const int   maximumSupportPoints=18;
const int   supportPointsSeparation=10;

#endif /* UserCommonProtocols_h */
