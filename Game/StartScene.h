//
//  StartScene.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/12/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef StartScene_hpp
#define StartScene_hpp

#include <stdio.h>
#include "U4DScene.h"
#include "U4DGameModelInterface.h"
#include "U4DTouchesController.h"
#include "U4DGamepadController.h"
#include "U4DKeyboardController.h"
#include "CommonProtocols.h"
#include "U4DDirector.h"

#include "StartMenu.h"
#include "StartLogic.h"

class StartScene:public U4DEngine::U4DScene {

private:
    
    StartMenu *startMenu;
    StartLogic *startLogic;
    
public:

    StartScene();
    
    ~StartScene();
    
    void init();
    
};

#endif /* StartScene_hpp */
