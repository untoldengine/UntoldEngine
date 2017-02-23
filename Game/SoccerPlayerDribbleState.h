//
//  SoccerPlayerDribbleState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/17/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerPlayerDribbleState_hpp
#define SoccerPlayerDribbleState_hpp

#include <stdio.h>
#include "SoccerPlayerStateInterface.h"

class SoccerPlayerDribbleState:public SoccerPlayerStateInterface {
    
protected:
    
    SoccerPlayerDribbleState();
    
    ~SoccerPlayerDribbleState();
    
public:
    
    static SoccerPlayerDribbleState* instance;
    
    static SoccerPlayerDribbleState* sharedInstance();
    
    void enter(SoccerPlayer *uPlayer);
    
    void execute(SoccerPlayer *uPlayer, double dt);
    
    void exit(SoccerPlayer *uPlayer);
    
    bool isSafeToChangeState(SoccerPlayer *uPlayer);
    
};

#endif /* SoccerPlayerDribbleState_hpp */
