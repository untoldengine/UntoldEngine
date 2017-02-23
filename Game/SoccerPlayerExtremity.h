//
//  SoccerPlayerExtremity.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/20/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerPlayerFeet_hpp
#define SoccerPlayerFeet_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class SoccerBall;

class SoccerPlayerExtremity:public U4DEngine::U4DGameObject {
    
private:
    
    std::string boneToFollow;
    
public:
    SoccerPlayerExtremity();
    
    ~SoccerPlayerExtremity();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    void setBoneToFollow(std::string uBoneName);
    
    std::string getBoneToFollow();
    
    float distanceToBall(SoccerBall *uSoccerBall);
    
};

#endif /* SoccerPlayerFeet_hpp */
