//
//  SoccerPlayerForwardKickState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/22/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerPlayerForwardKickState_hpp
#define SoccerPlayerForwardKickState_hpp

#include <stdio.h>
#include "SoccerPlayerStateInterface.h"

class SoccerPlayerForwardKickState:public SoccerPlayerStateInterface {
    
private:
    
    SoccerPlayerForwardKickState();
    
    ~SoccerPlayerForwardKickState();
    
public:
    
    static SoccerPlayerForwardKickState* instance;
    
    static SoccerPlayerForwardKickState* sharedInstance();
    
    void enter(SoccerPlayer *uPlayer);
    
    void execute(SoccerPlayer *uPlayer, double dt);
    
    void exit(SoccerPlayer *uPlayer);
    
};
#endif /* SoccerPlayerForwardKickState_hpp */
