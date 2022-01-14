//
//  U4DBall.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/17/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DBall_hpp
#define U4DBall_hpp

#include <stdio.h>
#include "U4DModel.h"
#include "U4DDynamicAction.h"
#include "CommonProtocols.h"


namespace U4DEngine {

class U4DBall:public U4DModel {
    
private:
    
    static U4DBall* instance;
    
    //state of the character
    int state;
    
    //previous state of the character
    int previousState;
    
    U4DVector3n motionAccumulator;
   
protected:
    
    //constructor
    U4DBall();
    //destructor
    
    ~U4DBall();
    
public:
    
    float kickMagnitude;
    
    U4DVector3n kickDirection;
    
    U4DDynamicAction *kineticAction;
    
    U4DVector3n homePosition;
    
    static U4DBall* sharedInstance();
    
    //init method. It loads all the rendering information among other things.
    bool init(const char* uModelName);
    
    void update(double dt);
    
    void applyForce(float uFinalVelocity, double dt);
    
    void applyVelocity(U4DVector3n &uFinalVelocity, double dt);
    
    void applyRoll(float uFinalVelocity,double dt);
    
    void decelerate(double dt);
    
    void setState(int uState);
    
    int getState();
    
    int getPreviousState();
    
    void changeState(int uState);
    
    void setKickBallParameters(float uKickMagnitude,U4DVector3n &uKickDirection);

    U4DVector3n predictPosition(double dt, float uTimeScale);
    
    float timeToCoverDistance(U4DVector3n &uFinalPosition);

    bool aiScored;
};
}

#endif /* U4DBall_hpp */
