//
//  U4DOpenGL3DModel.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DOpenGL3DModel__
#define __UntoldEngine__U4DOpenGL3DModel__

#include <iostream>
#include "U4DOpenGLManager.h"

namespace U4DEngine {
    
class U4DModel;

}

namespace U4DEngine {

/**
 @brief The U4DOpenGL3DModel class is in charge of rendering a 3D model entity
 */
class U4DOpenGL3DModel:public U4DOpenGLManager{
    
private:
    
    /**
     @brief Pointer representing the 3D model entity
     */
    U4DModel *u4dObject;
    
    /**
     @brief Light space matrix information
     */
    U4DMatrix4n lightSpaceMatrix;
    
    /**
     @brief Pointer to the index buffer
     */
    GLuint elementBuffer;
    
public:
   
    /**
     @brief Constructor for the class
     
     @param uWorld It takes as a paramenter the entity representing the 3D model entity
     */
    U4DOpenGL3DModel(U4DModel *uU4DModel);
    
    /**
     @brief Destructor for the class
     */
    ~U4DOpenGL3DModel();
    
    /**
     @brief Method which loads all Vertex Object Buffers used in rendering
     */
    void loadVertexObjectBuffer();
    
    /**
     @brief Method which loads all Texture Object Buffers used in rendering
     */
    void loadTextureObjectBuffer();
    
    /**
     @brief Method which enables the Vertices Attributes locations
     */
    void enableVerticesAttributeLocations();
    
    /**
     @brief Method which loads all Armature Uniforms locations used in rendering
     */
    void loadArmatureUniforms();
    
    /**
     @brief Method which loads all Light Uniform locations used in rendering
     */
    void loadLightsUniforms();
    
    /**
     @brief Method which loads bool variable stating that the entity has textures to render
     */
    void loadHasTextureUniform();
    
    /**
     @brief Method which starts the glDrawElements routine
     */
    void drawElements();
    
    /**
     @brief Method which activates the Texture Units used in rendering
     */
    void activateTexturesUniforms();
    
    /**
     @brief Method which sets the Normal-Map texture used for the entity
     
     @param uTexture Name of the Normal-Map texture
     */
    void setNormalBumpTexture(const char* uTexture);
    
    /**
     @brief Method which loads all Material Uniforms locations used in rendering
     */
    void loadMaterialsUniforms();
    
    /**
     @brief Method which returns the absolute space of the entity
     
     @return Returns the entity absolure space-Orientation and Position
     */
    U4DDualQuaternion getEntitySpace();
    
    /**
     @brief Method which returns the local space of the entity
     
     @return Returns the entity local space-Orientation and Position
     */
    U4DDualQuaternion getEntityLocalSpace();
    
    /**
     @brief Method which returns the absolute position of the entity
     
     @return Returns the entity absolute position
     */
    U4DVector3n getEntityAbsolutePosition();
    
    /**
     @brief Method which returns the local position of the entity
     
     @return Returns the entity local position
     */
    U4DVector3n getEntityLocalPosition();
    
    /**
     @brief Method which loads the Depth-Shadow uniform for shadow operations
     */
    void loadDepthShadowUniform();
    
    /**
     @brief Method which loads the shadow-bias uniform for shadow operations
     */
    void loadSelfShadowBiasUniform();
    
    /**
     @brief Method which starts the OpenGL rendering operations used for Shadows
     */
    void drawDepthOnFrameBuffer();

};
}

#endif /* defined(__UntoldEngine__U4DOpenGL3DModel__) */
