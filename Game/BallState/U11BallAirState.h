//
//  U11BallAirState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11BallAirState_hpp
#define U11BallAirState_hpp

#include <stdio.h>
#include "U11BallStateInterface.h"

class U11BallAirState:public U11BallStateInterface {
    
private:
    
    U11BallAirState();
    
    ~U11BallAirState();
    
public:
    
    static U11BallAirState* instance;
    
    static U11BallAirState* sharedInstance();
    
    void enter(U11Ball *uBall);
    
    void execute(U11Ball *uBall, double dt);
    
    void exit(U11Ball *uBall);
    
    bool isSafeToChangeState(U11Ball *uBall);
    
};
#endif /* U11BallAirState_hpp */
