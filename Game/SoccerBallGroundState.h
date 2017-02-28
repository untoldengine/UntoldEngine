//
//  SoccerBallGroundState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerBallGroundState_hpp
#define SoccerBallGroundState_hpp

#include <stdio.h>
#include "SoccerBallStateInterface.h"

class SoccerBallGroundState:public SoccerBallStateInterface {
    
private:
    
    SoccerBallGroundState();
    
    ~SoccerBallGroundState();
    
public:
    
    static SoccerBallGroundState* instance;
    
    static SoccerBallGroundState* sharedInstance();
    
    void enter(SoccerBall *uBall);
    
    void execute(SoccerBall *uBall, double dt);
    
    void exit(SoccerBall *uBall);
    
    bool isSafeToChangeState(SoccerBall *uBall);
    
};

#endif /* SoccerBallGroundState_hpp */
