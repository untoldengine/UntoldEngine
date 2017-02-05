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
    
    U4DEngine::U4DAnimation *kick;
    
    void setBallEntity(SoccerBall *uSoccerBall);
    
    inline void setJoystickData(U4DEngine::U4DVector3n& uData){joyStickData=uData;}
    
};
#endif /* SoccerPlayer_hpp */
