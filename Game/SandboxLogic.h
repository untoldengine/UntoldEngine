//
//  SandboxLogic.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/13/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef DebugLogic_hpp
#define DebugLogic_hpp

#include <stdio.h>
#include "U4DGameModel.h"
#include "U4DModel.h"

class SandboxLogic:public U4DEngine::U4DGameModel{
    
private:
    
    U4DEngine::U4DModel *pAstronaut;
    
    bool showBroadPhaseVolume;
    bool showNarrowPhaseVolume;
    
public:
    
    SandboxLogic();
    
    ~SandboxLogic();
    
    void update(double dt);
    
    void init();
    
    void receiveUserInputUpdate(void *uData);
    
};
#endif /* DebugLogic_hpp */
