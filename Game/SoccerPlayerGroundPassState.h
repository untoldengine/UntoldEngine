//
//  SoccerPlayerGroundPassState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerPlayerGroundPassState_hpp
#define SoccerPlayerGroundPassState_hpp

#include <stdio.h>
#include "SoccerPlayerStateInterface.h"

class SoccerPlayerGroundPassState:public SoccerPlayerStateInterface {
    
private:
    
    SoccerPlayerGroundPassState();
    
    ~SoccerPlayerGroundPassState();
    
public:
    
    static SoccerPlayerGroundPassState* instance;
    
    static SoccerPlayerGroundPassState* sharedInstance();
    
    void enter(SoccerPlayer *uPlayer);
    
    void execute(SoccerPlayer *uPlayer, double dt);
    
    void exit(SoccerPlayer *uPlayer);
    
};
#endif /* SoccerPlayerGroundPassState_hpp */
