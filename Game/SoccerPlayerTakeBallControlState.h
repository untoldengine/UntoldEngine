//
//  SoccerPlayerTakeBallControlState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerPlayerAdjustBallPositionState_hpp
#define SoccerPlayerAdjustBallPositionState_hpp

#include <stdio.h>
#include "SoccerPlayerStateInterface.h"

class SoccerPlayerTakeBallControlState:public SoccerPlayerStateInterface {
    
private:
    
    SoccerPlayerTakeBallControlState();
    
    ~SoccerPlayerTakeBallControlState();
    
public:
    
    static SoccerPlayerTakeBallControlState* instance;
    
    static SoccerPlayerTakeBallControlState* sharedInstance();
    
    void enter(SoccerPlayer *uPlayer);
    
    void execute(SoccerPlayer *uPlayer, double dt);
    
    void exit(SoccerPlayer *uPlayer);
    
};
#endif /* SoccerPlayerAdjustBallPositionState_hpp */
