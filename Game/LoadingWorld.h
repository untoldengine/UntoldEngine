//
//  LoadingWorld.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/19/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef LoadingWorld_hpp
#define LoadingWorld_hpp

#include <stdio.h>
#include "U4DWorld.h"
#include "U4DSpriteLoader.h"
#include "U4DImage.h"

class LoadingWorld:public U4DEngine::U4DWorld {
    
private:

    U4DEngine::U4DImage *loadingBackgroundImage;
    U4DEngine::U4DSpriteLoader *spriteLoader;
    
public:
    
    LoadingWorld();
    
    ~LoadingWorld();
    
    void init();
    
    void update(double dt);

    
};
#endif /* LoadingWorld_hpp */
