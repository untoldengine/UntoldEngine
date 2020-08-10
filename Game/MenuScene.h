//
//  MenuScene.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/2/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef MenuScene_hpp
#define MenuScene_hpp

#include <stdio.h>
#include "U4DScene.h"

#include "MenuWorld.h"
#include "MenuLogic.h"

#include "LoadingWorld.h"

class MenuScene:public U4DEngine::U4DScene {

private:
    
    MenuWorld *menuWorld;
    MenuLogic *menuLogic;
    LoadingWorld *loadingWorld;
    
public:

    MenuScene();
    
    ~MenuScene();
    
    void init();
    
};
#endif /* MenuScene_hpp */
