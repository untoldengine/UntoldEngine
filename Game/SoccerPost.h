//
//  SoccerPost.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/2/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef SoccerPost_hpp
#define SoccerPost_hpp

#include <stdio.h>
#include "U4DGameObject.h"
#include "UserCommonProtocols.h"

class SoccerPost:public U4DEngine::U4DGameObject {
    
private:
    
public:
    SoccerPost(){};
    ~SoccerPost(){};
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
};

#endif /* SoccerPost_hpp */
