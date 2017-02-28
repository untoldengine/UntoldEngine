//
//  SoccerBallAirState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerBallAirState_hpp
#define SoccerBallAirState_hpp

#include <stdio.h>
#include "SoccerBallStateInterface.h"

class SoccerBallAirState:public SoccerBallStateInterface {
    
private:
    
    SoccerBallAirState();
    
    ~SoccerBallAirState();
    
public:
    
    static SoccerBallAirState* instance;
    
    static SoccerBallAirState* sharedInstance();
    
    void enter(SoccerBall *uBall);
    
    void execute(SoccerBall *uBall, double dt);
    
    void exit(SoccerBall *uBall);
    
    bool isSafeToChangeState(SoccerBall *uBall);
    
};
#endif /* SoccerBallAirState_hpp */
