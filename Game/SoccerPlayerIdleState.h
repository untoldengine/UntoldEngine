//
//  SoccerPlayerIdleState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/18/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerPlayerIdleState_hpp
#define SoccerPlayerIdleState_hpp

#include <stdio.h>
#include "SoccerPlayerStateInterface.h"

class SoccerPlayerIdleState:public SoccerPlayerStateInterface {
    
private:
    
    SoccerPlayerIdleState();
    
    ~SoccerPlayerIdleState();
    
public:
    
    static SoccerPlayerIdleState* instance;
    
    static SoccerPlayerIdleState* sharedInstance();
    
    void enter(SoccerPlayer *uPlayer);
    
    void execute(SoccerPlayer *uPlayer, double dt);
    
    void exit(SoccerPlayer *uPlayer);
    
    bool isSafeToChangeState(SoccerPlayer *uPlayer);
    
};
#endif /* SoccerPlayerIdleState_hpp */
