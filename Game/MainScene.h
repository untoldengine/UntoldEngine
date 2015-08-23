//
//  MainScene.h
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__MainScene__
#define __UntoldEngine__MainScene__

#include <iostream>
#include "U4DScene.h"

class MainScene:public U4DEngine::U4DScene{
public:
    
    MainScene(){
    
        init();
    };
    
    void init();
private:
    
};

#endif /* defined(__UntoldEngine__MainScene__) */
