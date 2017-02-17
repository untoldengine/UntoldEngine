//
//  SoccerPlayerStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/17/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerPlayerStateManager_hpp
#define SoccerPlayerStateManager_hpp

#include <stdio.h>
#include "SoccerPlayerStateInterface.h"

class SoccerPlayer;

class SoccerPlayerStateManager {
    
private:
    
    SoccerPlayer *player;
    
    SoccerPlayerStateInterface *previousState;
    
    SoccerPlayerStateInterface *currentState;
    
public:
    
    SoccerPlayerStateManager(SoccerPlayer *uPlayer);
    
    ~SoccerPlayerStateManager();
    
    void changeState(SoccerPlayerStateInterface *uState);
    
    void execute();
    
    void setInitialState(SoccerPlayerStateInterface *uState);
};

#endif /* SoccerPlayerStateManager_hpp */
