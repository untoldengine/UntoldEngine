//
//  SoccerPlayerAirShotState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerPlayerAirShotState_hpp
#define SoccerPlayerAirShotState_hpp

#include <stdio.h>
#include "SoccerPlayerStateInterface.h"

class SoccerPlayerAirShotState:public SoccerPlayerStateInterface {
    
private:
    
    SoccerPlayerAirShotState();
    
    ~SoccerPlayerAirShotState();
    
public:
    
    static SoccerPlayerAirShotState* instance;
    
    static SoccerPlayerAirShotState* sharedInstance();
    
    void enter(SoccerPlayer *uPlayer);
    
    void execute(SoccerPlayer *uPlayer, double dt);
    
    void exit(SoccerPlayer *uPlayer);
    
    bool isSafeToChangeState(SoccerPlayer *uPlayer);
    
};

#endif /* SoccerPlayerAirShotState_hpp */
