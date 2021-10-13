//
//  SandboxScene.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/13/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef DebugScene_hpp
#define DebugScene_hpp

#include <stdio.h>
#include "U4DScene.h"

#include "CommonProtocols.h"
#include "SandboxWorld.h"
#include "SandboxLogic.h"
#include "SandboxLoading.h"

class SandboxScene:public U4DEngine::U4DScene {

private:
    
    SandboxWorld *sandboxWorld;
    SandboxLogic *sandboxLogic;
    SandboxLoading *loadingScene;
    
public:

    SandboxScene();
    
    ~SandboxScene();
    
    void init();
    
};
#endif /* DebugScene_hpp */
