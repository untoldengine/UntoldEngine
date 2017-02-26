//
//  SoccerPlayerReverseKickState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/24/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerPlayerReverseKickState_hpp
#define SoccerPlayerReverseKickState_hpp

#include <stdio.h>
#include "SoccerPlayerStateInterface.h"

class SoccerPlayerReverseKickState:public SoccerPlayerStateInterface {
    
private:
    
    SoccerPlayerReverseKickState();
    
    ~SoccerPlayerReverseKickState();
    
public:
    
    static SoccerPlayerReverseKickState* instance;
    
    static SoccerPlayerReverseKickState* sharedInstance();
    
    void enter(SoccerPlayer *uPlayer);
    
    void execute(SoccerPlayer *uPlayer, double dt);
    
    void exit(SoccerPlayer *uPlayer);
    
    bool isSafeToChangeState(SoccerPlayer *uPlayer);
    
};
#endif /* SoccerPlayerReverseKickState_hpp */
