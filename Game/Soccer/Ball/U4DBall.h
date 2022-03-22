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
#include "U4DGoalPost.h"
#include "CommonProtocols.h"
#include "U4DCallback.h"
#include "U4DTimer.h"

namespace U4DEngine {

class U4DBallStateInterface;
class U4DBallStateManager;

class U4DBall:public U4DModel {
    
private:
    
    static U4DBall* instance;
    
    U4DGoalPost *goalPostBallIsIn;
    
    U4DModel *obstacle;
    
    U4DCallback<U4DBall> *obstacleCollisionScheduler;
    
    
protected:
    
    //constructor
    U4DBall();
    //destructor
    
    ~U4DBall();
    
public:
    
    U4DBallStateManager *stateManager;
    
    U4DTimer *obstacleCollisionTimer;
    
    U4DVector3n motionAccumulator;
    
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
    
    void changeState(U4DBallStateInterface* uState);
    
    U4DBallStateInterface *getCurrentState();
    
    U4DBallStateInterface *getPreviousState();
    
    
    void setKickBallParameters(float uKickMagnitude,U4DVector3n &uKickDirection);

    U4DVector3n predictPosition(double dt, float uTimeScale);
    
    float timeToCoverDistance(U4DVector3n &uFinalPosition);

    bool aiScored;
    
    void insideGoalPost(U4DGoalPost *uGoalPost);
    
    U4DGoalPost *getBallInsideGoalPost();
    
    void setIntersectingObstacle(U4DModel *uObstacle);
    
    bool testObstacleIntersection();
    
    void testIfBallOnPlatform();
    
    void setViewDirection(U4DVector3n &uViewDirection);
    
};
}

#endif /* U4DBall_hpp */
