//
//  SoccerBallBounceState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/2/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerBallBounceState_hpp
#define SoccerBallBounceState_hpp

#include <stdio.h>
#include "SoccerBallStateInterface.h"

class SoccerBallBounceState:public SoccerBallStateInterface {
    
private:
    
    SoccerBallBounceState();
    
    ~SoccerBallBounceState();
    
public:
    
    static SoccerBallBounceState* instance;
    
    static SoccerBallBounceState* sharedInstance();
    
    void enter(SoccerBall *uBall);
    
    void execute(SoccerBall *uBall, double dt);
    
    void exit(SoccerBall *uBall);
    
    bool isSafeToChangeState(SoccerBall *uBall);
    
};
#endif /* SoccerBallBounceState_hpp */
