//
//  LevelOneScene.h
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__MainScene__
#define __UntoldEngine__MainScene__

#include <iostream>
#include "U4DScene.h"

#include "LevelOneWorld.h"
#include "LevelOneLogic.h"
#include "U4DGameModelInterface.h"
#include "U4DTouchesController.h"
#include "U4DGamepadController.h"
#include "U4DKeyboardController.h"
#include "CommonProtocols.h"
#include "U4DDirector.h"

#include "LoadingWorld.h"

class LevelOneScene:public U4DEngine::U4DScene{
    
private:
    
    LevelOneWorld *levelOneWorld;
    LoadingWorld *loadingWorld;
    U4DEngine::U4DGameModelInterface *levelOneLogic;
    
public:
    
    LevelOneScene();
    ~LevelOneScene();
    
    void init();
    
    
};

#endif /* defined(__UntoldEngine__MainScene__) */
