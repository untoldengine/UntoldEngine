//
//  U4DOpenGLWorld.h
//  UntoldEngine
//
//  Created by Harold Serrano on 1/13/15.
//  Copyright (c) 2015 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DOpenGLWorld__
#define __UntoldEngine__U4DOpenGLWorld__

#include <iostream>
#include "U4DOpenGLManager.h"

namespace U4DEngine {

class U4DWorld;

}

namespace U4DEngine {
    
class U4DOpenGLWorld:public U4DOpenGLManager{
    
private:
    
    U4DWorld *u4dWorld;
    
    GLuint offscreenFramebuffer;
    
public:
    
    U4DOpenGLWorld(U4DWorld *uWorld);
    
    ~U4DOpenGLWorld();
    
    void loadVertexObjectBuffer();
    
    void enableVerticesAttributeLocations();
    
    U4DDualQuaternion getEntitySpace();
    
    void drawElements();
    
    void startShadowMapPass();
    
    void endShadowMapPass();
    
    void initShadowMapFramebuffer();
    
};
    
}

#endif /* defined(__UntoldEngine__U4DOpenGLWorld__) */
