//
//  Castle.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/10/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef Castle_hpp
#define Castle_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class Castle:public U4DEngine::U4DGameObject {
    
private:
    
public:
    Castle();
    ~Castle();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
};
#endif /* Castle_hpp */
