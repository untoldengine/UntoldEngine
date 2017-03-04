//
//  U11BallGroundState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11BallGroundState_hpp
#define U11BallGroundState_hpp

#include <stdio.h>
#include "U11BallStateInterface.h"

class U11BallGroundState:public U11BallStateInterface {
    
private:
    
    U11BallGroundState();
    
    ~U11BallGroundState();
    
public:
    
    static U11BallGroundState* instance;
    
    static U11BallGroundState* sharedInstance();
    
    void enter(U11Ball *uBall);
    
    void execute(U11Ball *uBall, double dt);
    
    void exit(U11Ball *uBall);
    
    bool isSafeToChangeState(U11Ball *uBall);
    
};

#endif /* U11BallGroundState_hpp */
