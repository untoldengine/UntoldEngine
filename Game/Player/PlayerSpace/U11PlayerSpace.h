//
//  U11PlayerSpace.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/12/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U11PlayerSpace_hpp
#define U11PlayerSpace_hpp

#include <stdio.h>

#include "U4DGameObject.h"
#include "U4DAABB.h"

class U11PlayerSpace:public U4DEngine::U4DGameObject {
    
private:
    
    U4DEngine::U4DAABB playerSpaceBox;
    
public:
    
    U11PlayerSpace();
    
    ~U11PlayerSpace();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    U4DEngine::U4DAABB getUpdatedPlayerSpaceBox();
    
};

#endif /* U11PlayerSpace_hpp */
