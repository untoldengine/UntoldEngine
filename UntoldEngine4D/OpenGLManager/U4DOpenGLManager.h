//
//  U4DOpenGLManager.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DOpenGLManager__
#define __UntoldEngine__U4DOpenGLManager__

#include <iostream>
#include <string>
#include <vector>

#include "CommonProtocols.h"
#include "U4DEntity.h"
#include "U4DMatrix4n.h"
#include "U4DVector3n.h"  
#include "U4DVector4n.h" 
#include "U4DIndex.h"
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#define OPENGL_ES

namespace U4DEngine {
    
class U4DVector3n;
class U4DVector4n;
class U4DMatrix4n;
class U4DIndex;

}

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

namespace U4DEngine {

/**
 @brief The AttributeLocations structure contains OpenGL attribute locations used for rendering
 */
typedef struct{

    /**
     @brief Attribute location for vertices
     */
    GLint verticesAttributeLocation;
    
    /**
     @brief Attribute location for normal vectors
     */
    GLint normalAttributeLocation;
 
    /**
     @brief Attribute location for U-V coordinates
     */
    GLint uvAttributeLocation;

    /**
     @brief Attribute location for tangent vectors
     */
    GLint tangetVectorAttributeLocation;
    
    /**
     @brief Attribute location for OpenGL index rendering
     */
    GLint indexAttributeLocation;
    
    /**
     @brief Attribute location for Bone vertex weight. This is used for animation
     */
    GLint vertexWeightAttributeLocation;
    
    /**
     @brief Attribute location for Bone indices. This is used for animation
     */
    GLint boneIndicesAttributeLocation;
    
    /**
     @brief Attribute location for material indices.
     */
    GLint materialIndexAttributeLocation;
    
}AttributeLocations;

    /**
     @brief The ModelViewUniformLocations structure contains OpenGL Uniforms space information for rendering.
     */
typedef struct{
    
    /**
     @brief Uniform location which holds the Model space information
     */
    GLint modelUniformLocation;
    
    /**
     @brief Uniform location which holds the Model-View space information
     */
    GLint modelViewUniformLocation;
    
    /**
     @brief Uniform location which holds the Normal-View space information
     */
    GLint normaMatrixViewlUniformLocation;

    /**
     @brief Uniform location which holds the Model-View-Projection space information
     */
    GLint modelViewProjectionUniformLocation;
    
    /**
     @brief Uniform location which holds the current camera view direction information
     */
    GLint cameraViewDirectionUniformLocation;
    
}ModelViewUniformLocations;

/**
 @brief the MaterialUniformLocations structure contains material information used for rendering
 */
typedef struct {
    /**
     @brief Uniform location which holds the diffuse-color material information
     */
    GLint diffuseColorMaterialUniformLocation;
    
    /**
     @brief Uniform location which holds the specular-color material information
     */
    GLint specularColorMaterialUniformLocation;
    
    /**
     @brief Uniform location which holds the diffuse-intensity material information
     */
    GLint diffuseIntensityMaterialUniformLocation;
    
    /**
     @brief Uniform location which holds the specular-intensity material information
     */
    GLint specularIntensityMaterialUniformLocation;
    
    /**
     @brief Uniform location which holds the specular-shininess material information
     */
    GLint specularHardnessMaterialUniformLocation;
    
}MaterialUniformLocations;

/**
 @brief The TextureUniformLocations structure holds texture information used for rendering
 */
typedef struct{

    /**
     @brief Uniform location which serves as a bool variable to let the engine that the model has textures
     */
    GLint hasTextureUniformLocation;
    
    /**
     @brief Uniform location which holds emission-texture information.
     */
    GLint emissionTextureUniformLocation;
    
    /**
     @brief Uniform location which holds ambient-texture information
     */
    GLint ambientTextureUniformLocation;
    
    /**
     @brief Uniform location which holds diffuse-texture information
     */
    GLint diffuseTextureUniformLocation;
    
    /**
     @brief Uniform location which holds specular-texture information
     */
    GLint specularTextureUniformLocation;
    
    /**
     @brief Uniform location which holds normal-map texture information
     */
    GLint normalBumpTextureUniformLocation;
    
    /**
     @brief Uniform location which holds shadow-map texture information
     */
    GLint shadowMapTextureUniformLocation;
    
    /**
     @brief Uniform location which holds self-shadow bias information
     */
    GLint selfShadowBiasUniformLocation;
    
}TextureUniformLocations;

/**
 @brief The ArmatureUniformLocations structure holds armature/bone information for animation
 */
typedef struct{
    /**
     @brief Uniform location which serves as a bool variable to let the engine know that the model has an armature
     */
    GLint hasArmatureUniformLocation;
    
    /**
     @brief Uniform location which holds bone-matrix space information
     */
    GLint boneMatrixUniformLocation;
    
}ArmatureUniformLocations;

/**
 @brief The LightsUniformLocations structure holds light and shadow information used for rendering
 */
typedef struct{
    
    /**
     @brief Uniform location which holds the light position
     */
    GLint lightPositionUniformLocation;
    
    /**
     @brief Uniform location which holds the shadow current stage in the shaders
     */
    GLint shadowCurrentPassUniformLocation;
    
    /**
     @brief Uniform location which holds the light space information
     */
    GLint lightShadowDepthUniformLocation;
    
}LightsUniformLocations;
    
typedef struct{
    /**
     @brief Attribute location for vertices
     */
    GLint verticesAttributeLocation;
    
    GLint velocityAttributeLocation;
    
    GLint startTimeAttributeLocation;
    
}ParticleAttributeLocations;


}

namespace U4DEngine {

/**
 @brief  The U4DOpenGLManager class is in charge of implementing all OpenGL operations for every object.
 */
    
class U4DOpenGLManager{
    
private:
    
protected:
    
    /**
     @brief Pointer to the current active shader
     */
    GLuint shader;
 
    /**
     @brief Pointer to the Vertex Object Array
     */
    GLuint vertexObjectArray;

    /**
     @brief Pointer to the Vertex Object Buffer
     */
    GLuint vertexObjectBuffer;
    
    /**
     @brief Pointer to the Depth-Rendering Buffer
     */
    GLuint depthRenderbuffer;
    
    /**
     @brief Container holding custom uniform locations
     */
    std::vector<CUSTOMUNIFORMS> customUniforms;
    
    /**
     @brief Attribute locations
     */
    AttributeLocations attributeLocations;
    
    /**
     @brief Space Uniform locations
     */
    ModelViewUniformLocations modelViewUniformLocations;
    
    /**
     @brief Height of image
     */
    float imageHeight;
    
    /**
     @brief Width of image
     */
    float imageWidth;
    
    /**
     @brief Display screen width
     */
    float displayWidth;
    
    /**
     @brief Display screen height
     */
    float displayHeight;
    

public:
    
    /**
     @brief Array holding IDs for textures units
     */
    GLuint textureID[16];
    
    /**
     @brief Material Uniform location
     */
    MaterialUniformLocations materialUniformLocations;
    
    /**
     @brief Texture Uniform location
     */
    TextureUniformLocations textureUniformLocations;
    
    /**
     @brief Armature Uniform location
     */
    ArmatureUniformLocations armatureUniformLocations;
    
    /**
     @brief Light Uniform location
     */
    LightsUniformLocations lightUniformLocations;
    
    /**
     @brief Document this
     */
    ParticleAttributeLocations particleAttributeLocations;
    
    /**
     @brief Container holding all textures used in a skybox
     */
    std::vector<const char*> cubeMapTextures;
    
    /**
     @brief Constructor which creates an OpenGL Manager class
     */
    U4DOpenGLManager();

    /**
     @brief Destructor for the class
     */
    ~U4DOpenGLManager();

    /**
     @brief Copy constructor for the class
     @todo remove this
     */
    U4DOpenGLManager(const U4DOpenGLManager& value);
    
    /**
     @brief Copy constructor
     @todo remove this
     */
    U4DOpenGLManager& operator=(const U4DOpenGLManager& value);
    
    /**
     @brief Method which sets the active shader to use
     
     @param uShader Shader to use as the current shader
     */
    void setShader(std::string uShader);

    /**
     @brief Method which loads PNG images used for textures
     
     @param uTexture  Name of the texture to attach
     @param minFilter OpenGL Minification filter to use
     @param magFilter OpenGL Magnification filter to use
     @param wrapMode  OpenGL Wrapping Mode to use
     */
    void loadPNGTexture(std::string uTexture, GLenum minFilter, GLenum magFilter, GLenum wrapMode);

    /**
     @brief Method which loads all Vertex Object Buffers used in rendering
     */
    virtual void loadVertexObjectBuffer(){};
    
    /**
     @brief Method which updates all Vertex Object Buffers used in rendering
     */
    virtual void updateVertexObjectBuffer(){};

    /**
     @brief Method which loads all Texture Object Buffers used in rendering
     */
    virtual void loadTextureObjectBuffer(){};
    
    /**
     @brief Method which loads all Material Uniforms locations used in rendering
     */
    virtual void loadMaterialsUniforms(){};

    /**
     @brief Method which loads all Armature Uniforms locations used in rendering
     */
    virtual void loadArmatureUniforms(){};

    /**
     @brief Method which loads all Light Uniform locations used in rendering
     */
    virtual void loadLightsUniforms(){};
    
    /**
     @brief Method which loads bool variable stating that the entity has textures to render
     */
    virtual void loadHasTextureUniform(){};
    
    /**
     @brief Method which enables the Vertices Attributes locations
     */
    virtual void enableVerticesAttributeLocations(){};

    /**
     @brief Method which enables the Uniforms locations
     */
    virtual void enableUniformsLocations();

    /**
     @brief Method which starts the OpenGL rendering operations
     */
    virtual void draw();
    
    /**
     @brief Method which starts the OpenGL rendering operations used for Shadows
     */
    virtual void drawDepthOnFrameBuffer(){};
    
    /**
     @brief Method which starts the Shadow mapping rendering operation
     */
    virtual void startShadowMapPass(){};
    
    /**
     @brief Method which stops the Shadow mapping rendering operation
     */
    virtual void endShadowMapPass(){};
    
    /**
     @brief Method which initializes a framebuffer used for shadows
     */
    virtual void initShadowMapFramebuffer(){};
    
    /**
     @brief Method which returns the camera perspective projection space
     */
    virtual U4DMatrix4n getCameraPerspectiveView();

    /**
     @brief Method which starts the glDrawElements routine
     */
    virtual void drawElements(){};

    /**
     @brief Method which activates the Texture Units used in rendering
     */
    virtual void activateTexturesUniforms(){};
    
    /**
     @brief Method which returns the absolute space of the entity
     
     @return Returns the entity absolure space-Orientation and Position
     */
    virtual U4DDualQuaternion getEntitySpace(){};
    
    /**
     @brief Method which returns the local space of the entity
     
     @return Returns the entity local space-Orientation and Position
     */
    virtual U4DDualQuaternion getEntityLocalSpace(){};
    
    /**
     @brief Method which returns the absolute position of the entity
     
     @return Returns the entity absolute position
     */
    virtual U4DVector3n getEntityAbsolutePosition(){};
    
    /**
     @brief Method which returns the local position of the entity
     
     @return Returns the entity local position
     */
    virtual U4DVector3n getEntityLocalPosition(){};
    
    /**
     @brief Method which sets the diffuse-texture used for the entity
     
     @param uTexture Name of the diffuse-texture
     */
    virtual void setDiffuseTexture(const char* uTexture){};
    
    /**
     @brief Method which sets the ambient-texture used for the entity
     
     @param uTexture Name of the ambient-texture
     */
    virtual void setAmbientTexture(const char* uTexture){};
    
    /**
     @brief Method which sets the Normal-Map texture used for the entity
     
     @param uTexture Name of the Normal-Map texture
     */
    virtual void setNormalBumpTexture(const char* uTexture){};

    /**
     @brief Method which returns the camera space
     
     @return Returns the camera space-Orientation and Position
     */
    virtual U4DDualQuaternion getCameraSpace();
    
    /**
     @brief Method which returns the camera view direction
     
     @return Returns the camera view direction
     */
    U4DVector3n getCameraViewDirection();

    /**
     @brief Method which loads all rendering information used for the entity
     */
    void loadRenderingInformation();
    
    /**
     @brief Method which adds a custom uniform location
     
     @param uCustomUniforms uniform location to use
     
     @todo  Remove this method
     */
    void addCustomUniforms(CUSTOMUNIFORMS uCustomUniforms);
    
    /**
     @brief Method which enables custom uniform locations
     
     @todo Remove this method
     */
    void enableCustomUniforms();
    
    /**
     @brief Method which activates all custom uniform locations
     
     @todo  Remove this method
     */
    void getCustomUniforms();
    
    /**
     @brief Method which updates all cutoms uniform locations
     
     @param uName Name of the uniform location
     @param uData Data to update the uniform with
     
     @todo  Remove this method
     */
    void updateCustomUniforms(const char* uName,std::vector<float> uData);
    
    /**
     @brief Method which sets the dimension of the image(texture) to use
     
     @param uWidth  Image width
     @param uHeight Image height
     */
    virtual void setImageDimension(float uWidth,float uHeight){};
    
    /**
     @brief Method which update the dimesntion of the image
     
     @param uWidth  Image width
     @param uHeight Image height
     */
    virtual void updateImageDimension(float uWidth,float uHeight){};
    
    /**
     @brief Method which sets the image(texture) dimension found in an atlas texture
     
     @param uWidth       Image width
     @param uHeight      Image height
     @param uAtlasWidth  Atlas width
     @param uAtlasHeight Atlas height
     */
    virtual void setImageDimension(float uWidth,float uHeight, float uAtlasWidth,float uAtlasHeight){};
    
    /**
     @brief Method which update the image(texture) dimension found in an atlas texture
     
     @param uWidth       Image width
     @param uHeight      Image height
     @param uAtlasWidth  Atlas width
     @param uAtlasHeight Atlas height
     */
    virtual void updateImageDimension(float uWidth,float uHeight, float uAtlasWidth,float uAtlasHeight){};
    
    /**
     @brief Method which sets the dimension of the skybox(CubeMap)
     
     @param uSize Size of the cube map
     */
    virtual void setCubeMapDimension(float uSize){};
    
    /**
     @brief Method which activates multi-texture rendering
     
     @param value Boolean value to activate or deactivate multi-texture rendering
     */
    virtual void enableMultiTextures(bool value){};
    
    /**
     @brief Method which loads the Depth-Shadow uniform for shadow operations
     */
    virtual void loadDepthShadowUniform(){};
    
    /**
     @brief Method which loads the shadow-bias uniform for shadow operations
     */
    virtual void loadSelfShadowBiasUniform(){};
    
    /**
     @todo document this
     */
    void checkErrors(std::string uEntityName, std::string uOpenGLStage);
};

}

#endif /* defined(__UntoldEngine__U4DOpenGLManager__) */
