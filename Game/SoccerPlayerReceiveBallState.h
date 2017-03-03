//
//  SoccerPlayerReceiveBallState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/2/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerPlayerReceiveBallState_hpp
#define SoccerPlayerReceiveBallState_hpp

#include <stdio.h>
#include "SoccerPlayerStateInterface.h"

class SoccerPlayerReceiveBallState:public SoccerPlayerStateInterface {
    
private:
    
    SoccerPlayerReceiveBallState();
    
    ~SoccerPlayerReceiveBallState();
    
public:
    
    static SoccerPlayerReceiveBallState* instance;
    
    static SoccerPlayerReceiveBallState* sharedInstance();
    
    void enter(SoccerPlayer *uPlayer);
    
    void execute(SoccerPlayer *uPlayer, double dt);
    
    void exit(SoccerPlayer *uPlayer);
    
    bool isSafeToChangeState(SoccerPlayer *uPlayer);
    
};
#endif /* SoccerPlayerReceiveBallState_hpp */
