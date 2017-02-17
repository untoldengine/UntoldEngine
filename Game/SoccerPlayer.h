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

class SoccerPlayer:public U4DEngine::U4DGameObject {
    
private:
    
    GameEntityState entityState;
    U4DEngine::U4DVector3n joyStickData;
    SoccerBall *soccerBallEntity;
    
public:
    SoccerPlayer(){};
    ~SoccerPlayer(){};
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    void changeState(GameEntityState uState);
    
    void setState(GameEntityState uState);
    
    GameEntityState getState();
    
    U4DEngine::U4DAnimation *forwardKick;
    
    U4DEngine::U4DAnimation *walking;
    
    U4DEngine::U4DAnimation *sidePass;
    
    U4DEngine::U4DAnimation *running;
    
    U4DEngine::U4DAnimation *forwardCarry;
    
    U4DEngine::U4DAnimation *sideCarryLeft;
    
    U4DEngine::U4DAnimation *sideCarryRight;
    
    void setBallEntity(SoccerBall *uSoccerBall);
    
    void applyForceToPlayer(float uVelocity, double dt);
    
    inline void setJoystickData(U4DEngine::U4DVector3n& uData){joyStickData=uData;}
    
    U4DEngine::U4DAnimation *getRunningAnimation();
    
    U4DEngine::U4DAnimation *getSidePassAnimation();
    
};
#endif /* SoccerPlayer_hpp */
