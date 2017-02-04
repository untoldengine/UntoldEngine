//
//  SoccerPostSensor.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/2/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerPostSensor_hpp
#define SoccerPostSensor_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "UserCommonProtocols.h"
#include "SoccerBall.h"

class SoccerPostSensor:public U4DEngine::U4DGameObject {
    
private:
    SoccerBall *soccerBallEntity;
public:
    SoccerPostSensor(){
    
        setShader("nonVisibleShader");
    
    };
    
    ~SoccerPostSensor(){};
    
    void init(const char* uName, const char* uBlenderFile);
    
    void setBallEntity(SoccerBall *uSoccerBall);
    
    void update(double dt);
    
};
#endif /* SoccerPostSensor_hpp */
