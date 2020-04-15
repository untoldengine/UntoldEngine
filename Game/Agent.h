//
//  Agent.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/23/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef Agent_hpp
#define Agent_hpp

#include <stdio.h>
#include <vector>
#include "U4DGameObject.h"
#include "UserCommonProtocols.h"
#include "U4DAnimation.h"
#include "U4DAnimationManager.h"


class Agent:public U4DEngine::U4DGameObject{
    
private:
    
    //walking animation pointer
    U4DEngine::U4DAnimation *walkAnimation;
    
    U4DEngine::U4DAnimation *shootAnimation;
    
    //Animation Manager
    U4DEngine::U4DAnimationManager *animationManager;
    
    //state of the character
    int state;
    
    //force direction
    U4DEngine::U4DVector3n forceDirection;
    
    U4DEngine::U4DVector3n targetPosition;
    
    U4DEngine::U4DVector3n targetVelocity;
    
    U4DEngine::U4DVector3n wanderOrientation;
    
    U4DEngine::U4DVector3n motionAccumulator;
    
public:
    
    std::vector<Agent*> neighbors;
    
    Agent();
    
    ~Agent();
    
    bool init(const char* uModelName);
    
    void update(double dt);
    
    void setState(int uState);
    
    int getState();
    
    void changeState(int uState);
    
    void applyForce(float uFinalVelocity, double dt);
    
    void setForceDirection(U4DEngine::U4DVector3n &uForceDirection);
    
    void applyVelocity(U4DEngine::U4DVector3n &uFinalVelocity, double dt);
    
    void setTargetPosition(U4DEngine::U4DVector3n &uTargetPosition);
    
    void setViewDirection(U4DEngine::U4DVector3n &uViewDirection);
    
};

#endif /* Agent_hpp */
