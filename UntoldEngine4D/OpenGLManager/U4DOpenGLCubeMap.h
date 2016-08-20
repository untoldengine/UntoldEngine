//
//  U4DOpenGLCubeMap.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/15/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DOpenGLCubeMap__
#define __UntoldEngine__U4DOpenGLCubeMap__

#include <iostream>
#include "U4DOpenGLManager.h"

namespace U4DEngine {
class U4DSkyBox;
}

namespace U4DEngine {
    
class U4DOpenGLCubeMap:public U4DOpenGLManager{
    
private:
    
    GLenum  cubeMap[6] = {GL_TEXTURE_CUBE_MAP_POSITIVE_X,
        GL_TEXTURE_CUBE_MAP_NEGATIVE_X,
        GL_TEXTURE_CUBE_MAP_NEGATIVE_Z,
        GL_TEXTURE_CUBE_MAP_POSITIVE_Z,
        GL_TEXTURE_CUBE_MAP_POSITIVE_Y,
        GL_TEXTURE_CUBE_MAP_NEGATIVE_Y};
    
    U4DSkyBox *u4dObject;
    
public:
    
    U4DOpenGLCubeMap(U4DSkyBox *uU4DSkyBox);
    
    ~U4DOpenGLCubeMap();
    
    void loadTextureObjectBuffer();
    
    U4DDualQuaternion getEntitySpace();
    
    void loadVertexObjectBuffer();
    
    void enableVerticesAttributeLocations();
    
    void drawElements();
    
    void activateTexturesUniforms();
    
    virtual void setCubeMapDimension(float uSize);
    
    std::vector<unsigned char> loadCubeMapPNG(const char *uTexture);
    
};

}

#endif /* defined(__UntoldEngine__U4DOpenGLCubeMap__) */
