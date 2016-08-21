//
//  Cloud.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/21/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef Cloud_hpp
#define Cloud_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class Cloud:public U4DEngine::U4DGameObject {
    
private:
    
public:
    Cloud();
    ~Cloud();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
};
#endif /* Cloud_hpp */
