//
//  U11BallStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11BallStateManager_hpp
#define U11BallStateManager_hpp

#include <stdio.h>
#include "U11BallStateInterface.h"

class U11Ball;

class U11BallStateManager {
    
private:
    
    U11Ball *ball;
    
    U11BallStateInterface *previousState;
    
    U11BallStateInterface *currentState;
    
    U11BallStateInterface *nextState;
    
    bool changeStateRequest;
    
public:
    
    U11BallStateManager(U11Ball *uBall);
    
    ~U11BallStateManager();
    
    void changeState(U11BallStateInterface *uState);
    
    void update(double dt);
    
    bool isSafeToChangeState();
    
    void safeChangeState(U11BallStateInterface *uState);
};
#endif /* U11BallStateManager_hpp */
