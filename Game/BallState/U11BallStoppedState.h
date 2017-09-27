//
//  U11BallStoppedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/17/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11BallStoppedState_hpp
#define U11BallStoppedState_hpp

#include <stdio.h>
#include "U11BallStateInterface.h"

class U11BallStoppedState:public U11BallStateInterface {
    
private:
    
    U11BallStoppedState();
    
    ~U11BallStoppedState();
    
public:
    
    static U11BallStoppedState* instance;
    
    static U11BallStoppedState* sharedInstance();
    
    void enter(U11Ball *uBall);
    
    void execute(U11Ball *uBall, double dt);
    
    void exit(U11Ball *uBall);
    
    bool isSafeToChangeState(U11Ball *uBall);
    
};

#endif /* U11BallStoppedState_hpp */
