//
//  U4DSprite.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/27/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DSprite__
#define __UntoldEngine__U4DSprite__

#include <iostream>
#include <vector>
#include "U4DImage.h"
#include "U4DOpenGLSprite.h"
#include "U4DSpriteLoader.h"

namespace U4DEngine {
class U4DSpriteLoader;
}

namespace U4DEngine {
    
class U4DSprite:public U4DImage{
    
private:

    U4DSpriteLoader *spriteLoader;
    
public:
    
    U4DSprite(U4DSpriteLoader *uSpriteLoader);
    
    ~U4DSprite(){};
    
    const char* spriteImage;
    
    void setSprite(const char* uSprite);
    
    void changeSprite(const char* uSprite);
    
    void draw();
};

}

#endif /* defined(__UntoldEngine__U4DSprite__) */
