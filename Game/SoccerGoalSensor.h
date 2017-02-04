//
//  SoccerGoalSensor.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/2/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerGoalSensor_hpp
#define SoccerGoalSensor_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "UserCommonProtocols.h"
#include "SoccerBall.h"

class SoccerGoalSensor:public U4DEngine::U4DGameObject {
    
private:
    SoccerBall *soccerBallEntity;
public:
    SoccerGoalSensor(){};
    ~SoccerGoalSensor(){};
    
    void init(const char* uName, const char* uBlenderFile);
    
    void setBallEntity(SoccerBall *uSoccerBall);
    
    void update(double dt);
    
};
#endif /* SoccerGoalSensor_hpp */
