//
//  SoccerBall.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/28/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerBall_hpp
#define SoccerBall_hpp

#include <stdio.h>

#include "U4DGameObject.h"
#include "UserCommonProtocols.h"

class SoccerBallStateManager;
class SoccerBallStateInterface;

class SoccerBall:public U4DEngine::U4DGameObject {
    
private:
    
    GameEntityState entityState;
    
    U4DEngine::U4DVector3n kickDirection;
    
    float ballRadius;
    
    SoccerBallStateManager *stateManager;
    
    
public:
    
    SoccerBall();
    
    ~SoccerBall();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    void changeState(SoccerBallStateInterface* uState);
    
    bool isBallWithinRange();
    
    void moveBallWithinRange(double dt);

    void setKickDirection(U4DEngine::U4DVector3n &uDirection);
    
    float getBallRadius();
    
    void removeKineticForces();
    
    void kickBallToAir(float uVelocity, U4DEngine::U4DVector3n uDirection, double dt);
    
    void kickBallToGround(float uVelocity, U4DEngine::U4DVector3n uDirection, double dt);
    
    void decelerate(float uScale, double dt);
};

#endif /* SoccerBall_hpp */
