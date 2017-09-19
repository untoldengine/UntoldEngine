//
//  U11BallRollingState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11BallRollingState_hpp
#define U11BallRollingState_hpp

#include <stdio.h>
#include "U11BallStateInterface.h"

class U11BallRollingState:public U11BallStateInterface {
    
private:
    
    U11BallRollingState();
    
    ~U11BallRollingState();
    
public:
    
    static U11BallRollingState* instance;
    
    static U11BallRollingState* sharedInstance();
    
    void enter(U11Ball *uBall);
    
    void execute(U11Ball *uBall, double dt);
    
    void exit(U11Ball *uBall);
    
    bool isSafeToChangeState(U11Ball *uBall);
    
};

#endif /* U11BallRollingState_hpp */
