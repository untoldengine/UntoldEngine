//
//  UserCommonProtocols.h
//  UntoldEngine
//
//  Created by Harold Serrano on 10/16/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef UserCommonProtocols_h
#define UserCommonProtocols_h

typedef enum{
    
    kGroundPass,
    kAirPass,
    kStopped,
    kStabilize,
    kSleep,
    kBallHitGround,
    kBallHitPostSensor,
    kGoal,
    kWalking,
    kRunning,
    kAdvancingWithBall,
    kInPossesionOfBall,
    kNull
    
}GameEntityState;

typedef enum{

    kSoccerBall=1,
    kSoccerField=2,
    kSoccerPlayer=3,
    kSoccerPostSensor=4,
    kSoccerGoalSensor=5,
    kNegativeGroupIndex=-10,
    kPositiveGroupIndex=10,
    kZeroGroupIndex=0,

}GameEntityCollision;

const float fieldWidth=64.0;
const float fieldLength=128.0;

#endif /* UserCommonProtocols_h */
