//
//  Steps.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/10/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef Steps_hpp
#define Steps_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class Steps:public U4DEngine::U4DGameObject {
    
private:
    
public:
    Steps();
    ~Steps();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
};
#endif /* Steps_hpp */
