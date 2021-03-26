//
//  DemoScene.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/7/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef DemoScene_hpp
#define DemoScene_hpp

#include <stdio.h>
#include "U4DScene.h"

#include "CommonProtocols.h"
#include "DemoWorld.h"
#include "DemoLogic.h"
#include "DemoLoading.h"


class DemoScene:public U4DEngine::U4DScene {

private:
    
    DemoWorld *demoWorld;
    DemoLogic *demoLogic;
    DemoLoading *loadingScene;
    
public:

    DemoScene();
    
    ~DemoScene();
    
    void init();
    
};
#endif /* DemoScene_hpp */
