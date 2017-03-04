//
//  U11PlayerExtremity.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/20/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerFeet_hpp
#define U11PlayerFeet_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class U11Ball;

class U11PlayerExtremity:public U4DEngine::U4DGameObject {
    
private:
    
    std::string boneToFollow;
    
public:
    U11PlayerExtremity();
    
    ~U11PlayerExtremity();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    void setBoneToFollow(std::string uBoneName);
    
    std::string getBoneToFollow();
    
    float distanceToBall(U11Ball *uU11Ball);
    
};

#endif /* U11PlayerFeet_hpp */
