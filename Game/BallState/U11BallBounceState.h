//
//  U11BallBounceState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/2/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11BallBounceState_hpp
#define U11BallBounceState_hpp

#include <stdio.h>
#include "U11BallStateInterface.h"

class U11BallBounceState:public U11BallStateInterface {
    
private:
    
    U11BallBounceState();
    
    ~U11BallBounceState();
    
public:
    
    static U11BallBounceState* instance;
    
    static U11BallBounceState* sharedInstance();
    
    void enter(U11Ball *uBall);
    
    void execute(U11Ball *uBall, double dt);
    
    void exit(U11Ball *uBall);
    
    bool isSafeToChangeState(U11Ball *uBall);
    
};
#endif /* U11BallBounceState_hpp */
