//
//  U11BallStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11BallStateInterface_hpp
#define U11BallStateInterface_hpp

#include <stdio.h>
#include "U11Ball.h"

class U11BallStateInterface {
    
    
public:
    
    virtual ~U11BallStateInterface(){};
    
    virtual void enter(U11Ball *uBall)=0;
    
    virtual void execute(U11Ball *uBall, double dt)=0;
    
    virtual void exit(U11Ball *uBall)=0;
    
    virtual bool isSafeToChangeState(U11Ball *uBall)=0;
    
};
#endif /* U11BallStateInterface_hpp */
