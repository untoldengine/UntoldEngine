//
//  U4DOpenGLSprite.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/27/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DOpenGLSprite__
#define __UntoldEngine__U4DOpenGLSprite__

#include <iostream>
#include "U4DOpenGLImage.h"
#include "U4DOpenGLManager.h"

namespace U4DEngine {
    
class U4DOpenGLSprite:public U4DOpenGLImage{
    
private:
    
    U4DImage* u4dObject;
    
public:
    
    U4DOpenGLSprite(U4DImage* uU4DImage):U4DOpenGLImage(uU4DImage){
        u4dObject=uU4DImage; //attach the object to render
    };
    
    ~U4DOpenGLSprite(){};
    
    void setImageDimension(float uWidth,float uHeight, float uAtlasWidth,float uAtlasHeight);
    
};
    
}

#endif /* defined(__UntoldEngine__U4DOpenGLSprite__) */
