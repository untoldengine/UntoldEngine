//
//  U4DOpenGLMultiImage.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/28/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DOpenGLMultiImage__
#define __UntoldEngine__U4DOpenGLMultiImage__

#include <iostream>
#include "U4DOpenGLImage.h"
#include "U4DOpenGLManager.h"

namespace U4DEngine {
    
class U4DOpenGLMultiImage:public U4DOpenGLImage{
    
private:
    
    bool activateMultiTextureImage;
    
public:
    U4DOpenGLMultiImage(U4DImage *uU4DImage);
    ~U4DOpenGLMultiImage();
    
    void activateTexturesUniforms();
    void loadTextureObjectBuffer();
    virtual void setAmbientTexture(const char* uTexture);
    
    void setMultiImageActiveImage(bool value);
};
    
}

#endif /* defined(__UntoldEngine__U4DOpenGLMultiImage__) */
