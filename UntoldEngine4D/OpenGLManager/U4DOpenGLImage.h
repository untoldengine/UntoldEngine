//
//  U4DOpenGLImage.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DOpenGLImage__
#define __UntoldEngine__U4DOpenGLImage__

#include <iostream>
#include "U4DOpenGLManager.h"

namespace U4DEngine {
class U4DImage;
}

namespace U4DEngine {
    
class U4DOpenGLImage:public U4DOpenGLManager{
    
private:
    
protected:
    
    U4DImage *u4dObject;
    
public:
    
    U4DOpenGLImage(U4DImage *uU4DImage){
    
        u4dObject=uU4DImage;
        
    };
    
    ~U4DOpenGLImage(){};
    
    U4DMatrix4n getCameraProjection();
    
    U4DDualQuaternion getEntitySpace();
    
    void loadVertexObjectBuffer();
    
    void loadTextureObjectBuffer();
    
    void enableVerticesAttributeLocations();
    
    void drawElements();
    
    virtual void activateTexturesUniforms();
    
    virtual void setImageDimension(float uWidth,float uHeight);
    
    virtual void setDiffuseTexture(const char* uTexture);
    
    U4DDualQuaternion getCameraSpace();

    
};

}
    
#endif /* defined(__UntoldEngine__U4DOpenGLImage__) */
