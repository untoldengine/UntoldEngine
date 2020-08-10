//
//  Ball.hpp
//  Dribblr
//
//  Created by Harold Serrano on 5/31/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef Ball_hpp
#define Ball_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "UserCommonProtocols.h"


class Ball:public U4DEngine::U4DGameObject {
    
private:
    
    static Ball* instance;
    
    //state of the character
    int state;
    
    //previous state of the character
    int previousState;
    
    float kickMagnitude;
    
    U4DEngine::U4DVector3n kickDirection;
    
protected:
    
    //constructor
    Ball();
    //destructor
    
    ~Ball();
    
public:
    
    static Ball* sharedInstance();
    
    //init method. It loads all the rendering information among other things.
    bool init(const char* uModelName);
    
    void update(double dt);
    
    void applyForce(float uFinalVelocity, double dt);
    
    void applyRoll(float uFinalVelocity,double dt);
    
    void setState(int uState);
    
    int getState();
    
    int getPreviousState();
    
    void changeState(int uState);
    
    void setKickBallParameters(float uKickMagnitude,U4DEngine::U4DVector3n &uKickDirection);

};

#endif /* Ball_hpp */
