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
    U4DEngine::U4DAnimation *runningAnimation;
    
public:
    
    SoccerPlayer();
    
    ~SoccerPlayer();
    
    void init(const char* uModelName, const char* uBlenderFile, const char* uTextureNormal);
    
    void update(double dt);
    
    void playAnimation();
    
    void pauseAnimation();
    
    void setPlayerHeading(U4DEngine::U4DVector3n& uHeading);
    
    void applyForceToPlayer(float uVelocity, double dt);
    
};
#endif /* SoccerPlayer_hpp */
