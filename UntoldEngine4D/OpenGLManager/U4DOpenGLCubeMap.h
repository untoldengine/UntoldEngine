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
 
/**
 @brief The U4DOpenGLCubeMap class is in charge of rendering skyboxes(cubemaps) entities
 */
class U4DOpenGLCubeMap:public U4DOpenGLManager{
    
private:
    /**
     @brief Array which holds the textures for each of the 6 faces of the skybox
     */
    GLenum  cubeMap[6] = {GL_TEXTURE_CUBE_MAP_POSITIVE_X,
        GL_TEXTURE_CUBE_MAP_NEGATIVE_X,
        GL_TEXTURE_CUBE_MAP_NEGATIVE_Z,
        GL_TEXTURE_CUBE_MAP_POSITIVE_Z,
        GL_TEXTURE_CUBE_MAP_POSITIVE_Y,
        GL_TEXTURE_CUBE_MAP_NEGATIVE_Y};
    
    /**
     @brief Pointer representing the skybox entity
     */
    U4DSkyBox *u4dObject;
    
public:
    
    /**
     @brief Constructor for the class
     
     @param uU4DSkyBox It takes as a paramenter the entity representing the skybox entity
     */
    U4DOpenGLCubeMap(U4DSkyBox *uU4DSkyBox);
    
    /**
     @brief Destructor for the class
     */
    ~U4DOpenGLCubeMap();
    
    /**
     @brief Method which loads all Texture Object Buffers used in rendering
     */
    void loadTextureObjectBuffer();
    
    /**
     @brief Method which returns the absolute space of the entity
     
     @return Returns the entity absolure space-Orientation and Position
     */
    U4DDualQuaternion getEntitySpace();
    
    /**
     @brief Method which loads all Vertex Object Buffers used in rendering
     */
    void loadVertexObjectBuffer();
    
    /**
     @brief Method which enables the Vertices Attributes locations
     */
    void enableVerticesAttributeLocations();
    
    /**
     @brief Method which starts the glDrawElements routine
     */
    void drawElements();
    
    /**
     @brief Method which activates the Texture Units used in rendering
     */
    void activateTexturesUniforms();
    
    /**
     @brief Method which sets the dimension of the skybox(CubeMap)
     
     @param uSize Size of the cube map
     */
    virtual void setCubeMapDimension(float uSize);
    
    /**
     @brief Method which loads the texture image used as a skybox
     
     @param uTexture Name of texture
     
     @return Returns image data ready to be loaded in a texture object
     */
    std::vector<unsigned char> loadCubeMapPNG(const char *uTexture);
    
};

}

#endif /* defined(__UntoldEngine__U4DOpenGLCubeMap__) */
