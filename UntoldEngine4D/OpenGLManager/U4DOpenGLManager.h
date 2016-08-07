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


/**
 *  Class in charge of managing all OpenGL operations
 */

namespace U4DEngine {
    
typedef struct{
    
    GLint verticesAttributeLocation;
    
    GLint normalAttributeLocation;
 
    GLint uvAttributeLocation;

    GLint tangetVectorAttributeLocation;
    
    GLint indexAttributeLocation;
    
    GLint vertexWeightAttributeLocation;
    
    GLint boneIndicesAttributeLocation;
    
    GLint materialIndexAttributeLocation;
    
}AttibuteLocations;

typedef struct{
    
    GLint modelUniformLocation;
    
    GLint modelViewUniformLocation;
    
    GLint normaMatrixViewlUniformLocation;

    GLint modelViewProjectionUniformLocation;
    
    GLint cameraViewDirectionUniformLocation;
    
}ModelViewUniformLocations;

typedef struct {
    
    GLint diffuseColorMaterialUniformLocation;
    
    GLint specularColorMaterialUniformLocation;
    
    GLint diffuseIntensityMaterialUniformLocation;
    
    GLint specularIntensityMaterialUniformLocation;
    
    GLint specularHardnessMaterialUniformLocation;
    
}MaterialUniformLocations;

typedef struct{
    
    GLint hasTextureUniformLocation;
    
    GLint emissionTextureUniformLocation;
    
    GLint ambientTextureUniformLocation;
    
    GLint diffuseTextureUniformLocation;
    
    GLint specularTextureUniformLocation;
    
    GLint normalBumpTextureUniformLocation;
    
    GLint shadowMapTextureUniformLocation;
    
}TextureUniformLocations;

typedef struct{
    
    GLint boneMatrixUniformLocation;
    
}ArmatureUniformLocations;

typedef struct{
    
    GLint lightPositionUniformLocation;
    
    GLint shadowCurrentPassUniformLocation;
    
    GLint lightShadowDepthUniformLocation;
    
}LightsUniformLocations;

}

namespace U4DEngine {
    
class U4DOpenGLManager{
    
private:
    
protected:
 
    GLuint shader;
 
    GLuint vertexObjectArray;

    GLuint vertexObjectBuffer;
    
    GLuint offscreenFramebuffer;
    
    GLuint depthRenderbuffer;
    
    std::vector<CUSTOMUNIFORMS> customUniforms;
    
    AttibuteLocations attributeLocations;
    
    ModelViewUniformLocations modelViewUniformLocations;
    
    float imageHeight;
    float imageWidth;
    
    float displayWidth;
    float displayHeight;
    

public:
    
    GLuint textureID[16];
    
    MaterialUniformLocations materialUniformLocations;
    
    TextureUniformLocations textureUniformLocations;
    
    ArmatureUniformLocations armatureUniformLocations;
    
    LightsUniformLocations lightUniformLocations;
    
    std::vector<const char*> cubeMapTextures;
    
    U4DOpenGLManager();

    ~U4DOpenGLManager();

    U4DOpenGLManager(const U4DOpenGLManager& value){};
 
    U4DOpenGLManager& operator=(const U4DOpenGLManager& value){
        
        return *this;
    };
    
    void setShader(std::string uShader);

    void loadPNGTexture(std::string uTexture, GLenum minFilter, GLenum magFilter, GLenum wrapMode);

    virtual void loadVertexObjectBuffer(){};
    
    virtual void updateVertexObjectBuffer(){};

    virtual void loadTextureObjectBuffer(){};
    
    virtual void loadMaterialsUniforms(){};

    virtual void loadArmatureUniforms(){};

    virtual void loadLightsUniforms(){};
    
    virtual void loadHasTextureUniform(){};
    
    virtual void enableVerticesAttributeLocations(){};

    virtual void enableUniformsLocations();

    virtual void draw();
    
    virtual void drawDepthOnFrameBuffer(){};
    
    virtual void startShadowMapPass(){};
    
    virtual void endShadowMapPass(){};
    
    virtual void initShadowMapFramebuffer(){};
    
    virtual U4DMatrix4n getCameraProjection();

    virtual void drawElements(){};

    virtual void activateTexturesUniforms(){};
    
    virtual U4DDualQuaternion getEntitySpace(){};
    
    virtual U4DDualQuaternion getEntityLocalSpace(){};
    
    virtual U4DVector3n getEntityAbsolutePosition(){};
    
    virtual U4DVector3n getEntityLocalPosition(){};
    
    virtual void setDiffuseTexture(const char* uTexture){};
    virtual void setAmbientTexture(const char* uTexture){};
    virtual void setNormalBumpTexture(const char* uTexture){};

    virtual U4DDualQuaternion getCameraSpace();
    
    U4DVector3n getCameraViewDirection();

    void loadRenderingInformation();
    
    void addCustomUniforms(CUSTOMUNIFORMS uCustomUniforms);
    void enableCustomUniforms();
    void getCustomUniforms();
    void updateCustomUniforms(const char* uName,std::vector<float> uData);
    
    virtual void setImageDimension(float uWidth,float uHeight){};
    
    virtual void updateImageDimension(float uWidth,float uHeight){};
    
    virtual void setImageDimension(float uWidth,float uHeight, float uAtlasWidth,float uAtlasHeight){};
    
    virtual void updateImageDimension(float uWidth,float uHeight, float uAtlasWidth,float uAtlasHeight){};
    
    virtual void setCubeMapDimension(float uSize){};
    
    virtual void setMultiImageActiveImage(bool value){};
    
    virtual void loadDepthShadowUniform(){};
};

}

#endif /* defined(__UntoldEngine__U4DOpenGLManager__) */
