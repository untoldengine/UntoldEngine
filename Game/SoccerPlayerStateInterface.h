//
//  SoccerPlayerStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/17/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerPlayerStateInterface_hpp
#define SoccerPlayerStateInterface_hpp

#include <stdio.h>
#include "SoccerPlayer.h"

class SoccerPlayerStateInterface {
    
    
public:
    
    virtual ~SoccerPlayerStateInterface(){};
    
    virtual void enter(SoccerPlayer *uPlayer)=0;
    
    virtual void execute(SoccerPlayer *uPlayer, double dt)=0;
    
    virtual void exit(SoccerPlayer *uPlayer)=0;
    
    virtual bool isSafeToChangeState(SoccerPlayer *uPlayer)=0;
    
};

#endif /* SoccerPlayerStateInterface_hpp */
