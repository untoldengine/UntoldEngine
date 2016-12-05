//
//  U4DOpenGLManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DOpenGLManager.h"
#include "lodepng.h"
#include "CommonProtocols.h"
#include "U4DDirector.h"
#include "U4DCamera.h"
#include "U4DLights.h"
#include "U4DDualQuaternion.h"
#include "U4DLogger.h"

namespace U4DEngine {
    
U4DOpenGLManager::U4DOpenGLManager(){

    U4DDirector *director=U4DDirector::sharedInstance();
    
    displayWidth=director->getDisplayWidth();
    displayHeight=director->getDisplayHeight();
    
}

U4DOpenGLManager::~U4DOpenGLManager(){

    //delete the buffer
    glDeleteBuffers(1, &vertexObjectBuffer);
    
}
    
U4DOpenGLManager::U4DOpenGLManager(const U4DOpenGLManager& value){

}

U4DOpenGLManager& U4DOpenGLManager::operator=(const U4DOpenGLManager& value){
    
    return *this;
}


#pragma mark-setShader
void U4DOpenGLManager::setShader(std::string uShader){
    
    U4DDirector *director=U4DDirector::sharedInstance();
    shader=director->getShaderProgram(uShader);

}

#pragma mark-body assembly
void U4DOpenGLManager::loadRenderingInformation(){
    
    loadVertexObjectBuffer();
    loadTextureObjectBuffer();
    enableVerticesAttributeLocations();
    enableUniformsLocations();
    
    glBindVertexArray(0);
    
}


void U4DOpenGLManager::enableUniformsLocations(){
    
    
    //Model Uniform Location
     modelViewUniformLocations.modelUniformLocation=glGetUniformLocation(shader,"ModelMatrix");  //model matrix
    
    //Model View Uniform Locations
    modelViewUniformLocations.modelViewUniformLocation=glGetUniformLocation(shader,"MVMatrix");  //model-view matrix
    
    modelViewUniformLocations.modelViewProjectionUniformLocation=glGetUniformLocation(shader,"MVPMatrix"); //model-view-projection matrix
    
    modelViewUniformLocations.normaMatrixViewlUniformLocation=glGetUniformLocation(shader, "NormalMatrix"); //normal matrix
    
    modelViewUniformLocations.cameraViewDirectionUniformLocation=glGetUniformLocation(shader, "CameraViewDirection");  //camera view direction

    //Texture Uniform Locations
    textureUniformLocations.hasTextureUniformLocation=glGetUniformLocation(shader, "HasTexture");
    textureUniformLocations.emissionTextureUniformLocation=glGetUniformLocation(shader, "EmissionTexture");
    textureUniformLocations.ambientTextureUniformLocation=glGetUniformLocation(shader, "AmbientTexture");
    textureUniformLocations.diffuseTextureUniformLocation=glGetUniformLocation(shader, "DiffuseTexture");
    textureUniformLocations.specularTextureUniformLocation=glGetUniformLocation(shader, "SpecularTexture");
    textureUniformLocations.normalBumpTextureUniformLocation=glGetUniformLocation(shader, "NormalBumpTexture");
    textureUniformLocations.shadowMapTextureUniformLocation=glGetUniformLocation(shader, "ShadowMap");
    textureUniformLocations.selfShadowBiasUniformLocation=glGetUniformLocation(shader, "SelfShadowBias");
    
    //Material Uniform Locations
    materialUniformLocations.diffuseColorMaterialUniformLocation=glGetUniformLocation(shader, "DiffuseMaterialColor");
    materialUniformLocations.specularColorMaterialUniformLocation=glGetUniformLocation(shader, "SpecularMaterialColor");
    materialUniformLocations.diffuseIntensityMaterialUniformLocation=glGetUniformLocation(shader, "DiffuseMaterialIntensity");
    materialUniformLocations.specularIntensityMaterialUniformLocation=glGetUniformLocation(shader, "SpecularMaterialIntensity");
    materialUniformLocations.specularHardnessMaterialUniformLocation=glGetUniformLocation(shader, "SpecularMaterialHardness");
    
    //Animations Uniform Locations
    armatureUniformLocations.boneMatrixUniformLocation=glGetUniformLocation(shader, "BoneMatrix");
    armatureUniformLocations.hasArmatureUniformLocation=glGetUniformLocation(shader, "HasArmature");
    
    //set up the light position uniform
    lightUniformLocations.lightPositionUniformLocation=glGetUniformLocation(shader, "PointLight");
    
    
    //shadow current pass uniform
    lightUniformLocations.shadowCurrentPassUniformLocation=glGetUniformLocation(shader, "ShadowCurrentPass");
    
    //set up shadow uniform location
    lightUniformLocations.lightShadowDepthUniformLocation=glGetUniformLocation(shader, "LightShadowSpaceMatrix");
    
}

void U4DOpenGLManager::addCustomUniforms(CUSTOMUNIFORMS uCustomUniforms){
    
    customUniforms.push_back(uCustomUniforms);
    
    enableCustomUniforms();

}

void U4DOpenGLManager::enableCustomUniforms(){
    
    for (int i=0; i<customUniforms.size(); i++) {
        
        customUniforms[i].location=glGetUniformLocation(shader, customUniforms[i].name);
        
        GLint loc=customUniforms[i].location;
        
        if (customUniforms[i].data.size()==1) {
            
            //float
            glUniform1f(loc, customUniforms[i].data[0]);
            
        }else if (customUniforms[i].data.size()==2){
            
            //vec2
            glUniform2fv(loc, 1, &customUniforms[i].data[0]);
            
        }else if (customUniforms[i].data.size()==3){
            //vec3
            glUniform3fv(loc, 1, &customUniforms[i].data[0]);
            
        }else if (customUniforms[i].data.size()==4){
            //vec4
            glUniform4fv(loc, 1,&customUniforms[i].data[0]);
        }
        
    }
    
}

void U4DOpenGLManager::updateCustomUniforms(const char* uName,std::vector<float> uData){
    
    for (int i=0; i<customUniforms.size(); i++) {
        
        if (customUniforms[i].name==uName) {
            
            customUniforms[i].data=uData;
            GLint loc=glGetUniformLocation(shader, uName);
            
            if (customUniforms[i].data.size()==1) {
                
                glUniform1f(loc, customUniforms[i].data[0]);
                
            }else if (customUniforms[i].data.size()==2){
                
                glUniform2fv(loc, 1, &customUniforms[i].data[0]);
                
            }else if (customUniforms[i].data.size()==3){
                
                glUniform3fv(loc, 1, &customUniforms[i].data[0]);
                
            }else if (customUniforms[i].data.size()==4){
                
                glUniform4fv(loc, 1,&customUniforms[i].data[0]);
                
            }
            
        }
    }
    
}

void U4DOpenGLManager::getCustomUniforms(){
    
    for (int i=0; i<customUniforms.size(); i++) {
        
        GLint loc=customUniforms[i].location;
        
        if (customUniforms[i].data.size()==1) {
            
            glUniform1f(loc, customUniforms[i].data[0]);
            
        }else if (customUniforms[i].data.size()==2){
            
            glUniform2fv(loc, 1, &customUniforms[i].data[0]);
            
        }else if (customUniforms[i].data.size()==3){
            
            glUniform3fv(loc, 1, &customUniforms[i].data[0]);
            
        }else if (customUniforms[i].data.size()==4){
            
            glUniform4fv(loc, 1,&customUniforms[i].data[0]);
            
        }
        
    }
    
}


U4DMatrix4n U4DOpenGLManager::getCameraPerspectiveView(){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    
    return camera->getCameraPerspectiveView();
}

U4DDualQuaternion U4DOpenGLManager::getCameraSpace(){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    U4DDualQuaternion cameraQuaternion;
    cameraQuaternion=camera->getLocalSpace();
    
    return cameraQuaternion;
}
    
U4DVector3n U4DOpenGLManager::getCameraViewDirection(){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    return camera->getViewInDirection();
    
}


#pragma mark-draw
void U4DOpenGLManager::draw(){
    
    
    glUseProgram(shader);
    
    glBindVertexArray(vertexObjectArray);
    
    loadMaterialsUniforms();
    
    activateTexturesUniforms();

    //get Model matrix
    U4DDualQuaternion mModel=getEntitySpace();
    
    U4DMatrix4n mModelMatrix=mModel.transformDualQuaternionToMatrix4n();
    
    //get camera matrix
    U4DMatrix4n cameraMatrix=getCameraSpace().transformDualQuaternionToMatrix4n();
    
    cameraMatrix.invert();
    
    //U4DDualQuaternion mModelWorldView=mModel*getCameraSpace();
    
    U4DMatrix4n mModelViewMatrix=cameraMatrix*mModelMatrix;
    
    
    //extract the 3x3 matrix
    U4DMatrix3n modelViewMatrix3x3=mModelViewMatrix.extract3x3Matrix();
    
    //Normal Matrix=get the inverse and transpose it
    
    U4DMatrix3n normalModelViewMatrix;
    
    modelViewMatrix3x3.invert();
    
    normalModelViewMatrix=modelViewMatrix3x3.transpose();
    
    //get the mvp
    U4DMatrix4n mModelViewProjection;

    mModelViewProjection=getCameraPerspectiveView()*mModelViewMatrix;
    
    //get the camera view direction
    U4DVector3n cameraViewDirection=getCameraViewDirection();
    
    glUniformMatrix4fv(modelViewUniformLocations.modelUniformLocation,1,0,mModelMatrix.matrixData);
    
    glUniformMatrix4fv(modelViewUniformLocations.modelViewUniformLocation,1,0,mModelViewMatrix.matrixData);
    
    glUniformMatrix4fv(modelViewUniformLocations.modelViewProjectionUniformLocation,1,0,mModelViewProjection.matrixData);
    
    glUniformMatrix3fv(modelViewUniformLocations.normaMatrixViewlUniformLocation,1,0,normalModelViewMatrix.matrixData);
    
    glUniform1f(lightUniformLocations.shadowCurrentPassUniformLocation, 1.0);
    
    glUniform3f(modelViewUniformLocations.cameraViewDirectionUniformLocation, cameraViewDirection.x, cameraViewDirection.y, cameraViewDirection.z);
    
    //load shadow information
    loadDepthShadowUniform();
    
    loadSelfShadowBiasUniform();
    
    //load armature data
    loadArmatureUniforms();
    
    //load lights data
    loadLightsUniforms();
    
    //load has texture data
    loadHasTextureUniform();
    
    //get custom uniforms
    getCustomUniforms();
    
    //draw elements
    drawElements();
    
    glBindVertexArray(0);
    
}


#pragma mark-Load the texture

void U4DOpenGLManager::loadPNGTexture(std::string uTexture, GLenum minFilter, GLenum magFilter, GLenum wrapMode){
    
    // Load file and decode image.
    std::vector<unsigned char> image;
    unsigned int width=0;
    unsigned int height=0;
    
    const char * textureImage = uTexture.c_str();
    
    unsigned error = lodepng::decode(image, width, height,textureImage);
    
    //if there's an error, display it
    if(error){
        std::cout << "decoder error " << error << ": " <<uTexture<<" file is "<< lodepng_error_text(error) << std::endl;
    }else{
        
        /*
        // Texture size must be power of two for the primitive OpenGL version this is written for. Find next power of two.
        size_t u2 = 1; while(u2 < width) u2 *= 2;
        size_t v2 = 1; while(v2 < height) v2 *= 2;
        // Ratio for power of two version compared to actual version, to render the non power of two image with proper size.
        //double u3 = (double)width / u2;
        //double v3 = (double)height / v2;
        
        // Make power of two version of the image.
        std::vector<unsigned char> image2(u2 * v2 * 4);
        for(size_t y = 0; y < height; y++)
            for(size_t x = 0; x < width; x++)
                for(size_t c = 0; c < 4; c++)
                {
                    image2[4 * u2 * y + 4 * x + c] = image[4 * width * y + 4 * x + c];
                }
        */
        
        //Flip and invert the image
        unsigned char* imagePtr=&image[0];
        
        int halfTheHeightInPixels=height/2;
        int heightInPixels=height;
        
        
        //Assume RGBA for 4 components per pixel
        int numColorComponents=4;
        
        //Assuming each color component is an unsigned char
        int widthInChars=width*numColorComponents;
        
        unsigned char *top=NULL;
        unsigned char *bottom=NULL;
        unsigned char temp=0;
        
        for( int h = 0; h < halfTheHeightInPixels; ++h )
        {
            top = imagePtr + h * widthInChars;
            bottom = imagePtr + (heightInPixels - h - 1) * widthInChars;
            
            for( int w = 0; w < widthInChars; ++w )
            {
                // Swap the chars around.
                temp = *top;
                *top = *bottom;
                *bottom = temp;
                
                ++top;
                ++bottom;
            }
        }
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, wrapMode);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, wrapMode);
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, minFilter);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, magFilter);
        
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0,
                     GL_RGBA, GL_UNSIGNED_BYTE, &image[0]);
        
    
        imageWidth=width;
        imageHeight=height;
    }
    
    image.clear();
}
    
    void U4DOpenGLManager::checkErrors(std::string uEntityName, std::string uOpenGLStage){
        
        GLenum errorCode;
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        
        while ( ( errorCode = glGetError() ) != GL_NO_ERROR) {
            
            std::string error;
            
            switch (errorCode) {
                case GL_INVALID_ENUM:
                    
                    error="The enum argument is out of range (GL_INVALID_ENUM)";
                    
                    break;
                    
                case GL_INVALID_VALUE:
                    
                    error="The numeric argument is out of range (GL_INVALID_VALUE)";
                    
                    break;
                    
                case GL_INVALID_OPERATION:
                    
                    error="The operation is illegal in its current state (GL_INVALID_OPERATION)";
                    
                    break;
                    
                case GL_OUT_OF_MEMORY:
                    
                    error="Not enough memory is left to execute the command (GL_OUT_OF_MEMORY)";
                    
                    break;
                    
                default:
                    
                    error="There was an error but couldn't determine it what";
                    
                    break;
            }
            
            logger->log("OPENGL ERROR: %s for entity %s while performing %s",error.c_str(), uEntityName.c_str(), uOpenGLStage.c_str());
            
        }
    }

}

