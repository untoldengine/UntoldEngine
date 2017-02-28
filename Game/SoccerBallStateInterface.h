//
//  SoccerBallStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerBallStateInterface_hpp
#define SoccerBallStateInterface_hpp

#include <stdio.h>
#include "SoccerBall.h"

class SoccerBallStateInterface {
    
    
public:
    
    virtual ~SoccerBallStateInterface(){};
    
    virtual void enter(SoccerBall *uBall)=0;
    
    virtual void execute(SoccerBall *uBall, double dt)=0;
    
    virtual void exit(SoccerBall *uBall)=0;
    
    virtual bool isSafeToChangeState(SoccerBall *uBall)=0;
    
};
#endif /* SoccerBallStateInterface_hpp */
