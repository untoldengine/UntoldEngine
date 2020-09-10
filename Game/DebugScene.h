//
//  DebugScene.hpp
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
#include "DebugWorld.h"
#include "DebugLogic.h"



class DebugScene:public U4DEngine::U4DScene {

private:
    
    DebugWorld *debugWorld;
    DebugLogic *debugLogic;
    
    
public:

    DebugScene();
    
    ~DebugScene();
    
    void init();
    
};
#endif /* DebugScene_hpp */
