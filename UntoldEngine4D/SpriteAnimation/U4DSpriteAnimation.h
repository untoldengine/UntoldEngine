//
//  U4DSpriteAnimation.h
//  UntoldEngine
//
//  Created by Harold Serrano on 4/23/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DSpriteAnimation__
#define __UntoldEngine__U4DSpriteAnimation__

#include <iostream>
#include "CommonProtocols.h"
#include "U4DSprite.h"
#include "U4DCallback.h"

namespace U4DEngine {
    
class U4DSpriteAnimation{
    
private:
    
    int spriteAnimationFrame;
    U4DSprite *sprite;
    SpriteAnimation spriteAnimation;
    U4DTimer *timer;
    U4DCallback<U4DSpriteAnimation> *scheduler;
    
public:
    
    U4DSpriteAnimation(U4DSprite *uSprite, SpriteAnimation &uSpriteAnimation);
    
    
    ~U4DSpriteAnimation();
    
   
    void runAnimation();
    void start();
    void stop();
    
};

}

#endif /* defined(__UntoldEngine__U4DSpriteAnimation__) */
