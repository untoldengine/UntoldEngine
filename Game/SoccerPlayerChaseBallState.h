//
//  SoccerPlayerChaseBallState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/17/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerPlayerChaseBallState_hpp
#define SoccerPlayerChaseBallState_hpp

#include <stdio.h>
#include "SoccerPlayerStateInterface.h"

class SoccerPlayerChaseBallState:public SoccerPlayerStateInterface {
    
public:
    
    SoccerPlayerChaseBallState();
    
    ~SoccerPlayerChaseBallState();
    
    void enter(SoccerPlayer *uPlayer);
    
    void execute(SoccerPlayer *uPlayer);
    
    void exit(SoccerPlayer *uPlayer);
    
};

#endif /* SoccerPlayerChaseBallState_hpp */
