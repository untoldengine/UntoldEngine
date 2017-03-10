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
    msgPassToMe
    
}MessageEnum;

const float fieldWidth=64.0;
const float fieldLength=128.0;

const float chasingSpeed=30.0;
const float dribblingSpeed=20.0;
const float ballRollingSpeed=24.0;
const float ballPassingSpeed=50.0;
const float ballGroundShotSpeed=70.0;
const float ballAirShotSpeed=30.0;
const float ballReverseRolling=15.0;
const float ballDeceleration=0.5;
const float ballMaxSpeedMagnitude=8.0;

#endif /* UserCommonProtocols_h */
