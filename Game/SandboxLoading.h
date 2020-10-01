//
//  SandboxLoading.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/30/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef SandboxLoading_hpp
#define SandboxLoading_hpp

#include <stdio.h>
#include "U4DWorld.h"
#include "U4DImage.h"

class SandboxLoading:public U4DEngine::U4DWorld {
    
private:

    U4DEngine::U4DImage *loadingBackgroundImage;
    
public:
    
    SandboxLoading();
    
    ~SandboxLoading();
    
    void init();
    
    void update(double dt);

    
};
#endif /* SandboxLoading_hpp */
