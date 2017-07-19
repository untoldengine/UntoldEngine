//
//  SoccerPlayer.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerPlayer_hpp
#define SoccerPlayer_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class SoccerPlayer:public U4DEngine::U4DGameObject {
    
private:
    
    U4DEngine::U4DAnimation *walkingAnimation;
    
public:
    
    SoccerPlayer();
    
    ~SoccerPlayer();
    
    void init(const char* uModelName, const char* uBlenderFile);
    
    void update(double dt);
    
    void playAnimation();
    
};
#endif /* SoccerPlayer_hpp */
