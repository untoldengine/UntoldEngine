//
//  SoccerPlayerFeet.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/20/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerPlayerFeet_hpp
#define SoccerPlayerFeet_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class SoccerPlayerFeet:public U4DEngine::U4DGameObject {
    
private:
    
public:
    SoccerPlayerFeet();
    
    ~SoccerPlayerFeet();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    
};

#endif /* SoccerPlayerFeet_hpp */
