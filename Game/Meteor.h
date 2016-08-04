//
//  Meteor.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/4/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef Meteor_hpp
#define Meteor_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class Meteor:public U4DEngine::U4DGameObject {
    
private:
    
public:
    Meteor();
    ~Meteor();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
};
#endif /* Meteor_hpp */
