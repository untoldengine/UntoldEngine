//
//  SoccerBallStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerBallStateManager_hpp
#define SoccerBallStateManager_hpp

#include <stdio.h>
#include "SoccerBallStateInterface.h"

class SoccerBall;

class SoccerBallStateManager {
    
private:
    
    SoccerBall *ball;
    
    SoccerBallStateInterface *previousState;
    
    SoccerBallStateInterface *currentState;
    
    SoccerBallStateInterface *nextState;
    
    bool changeStateRequest;
    
public:
    
    SoccerBallStateManager(SoccerBall *uBall);
    
    ~SoccerBallStateManager();
    
    void changeState(SoccerBallStateInterface *uState);
    
    void update(double dt);
    
    bool isSafeToChangeState();
    
    void safeChangeState(SoccerBallStateInterface *uState);
};
#endif /* SoccerBallStateManager_hpp */
