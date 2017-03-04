//
//  U11Ball.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/28/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11Ball_hpp
#define U11Ball_hpp

#include <stdio.h>

#include "U4DGameObject.h"
#include "UserCommonProtocols.h"

class U11BallStateManager;
class U11BallStateInterface;

class U11Ball:public U4DEngine::U4DGameObject {
    
private:
    
    U4DEngine::U4DVector3n kickDirection;
    
    float ballRadius;
    
    U11BallStateManager *stateManager;
    
    
public:
    
    U11Ball();
    
    ~U11Ball();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    void changeState(U11BallStateInterface* uState);
    
    bool isBallWithinRange();
    
    void moveBallWithinRange(double dt);

    void setKickDirection(U4DEngine::U4DVector3n &uDirection);
    
    float getBallRadius();
    
    void removeKineticForces();
    
    void removeAllVelocities();
    
    void kickBallToAir(float uVelocity, U4DEngine::U4DVector3n uDirection, double dt);
    
    void kickBallToGround(float uVelocity, U4DEngine::U4DVector3n uDirection, double dt);
    
    void decelerate(float uScale, double dt);
};

#endif /* U11Ball_hpp */
