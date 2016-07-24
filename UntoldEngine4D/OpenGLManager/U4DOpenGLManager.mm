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

namespace U4DEngine {
    
U4DOpenGLManager::U4DOpenGLManager(){

    U4DDirector *director=U4DDirector::sharedInstance();
    
    displayWidth=director->getDisplayWidth();
    displayHeight=director->getDisplayHeight();
    
    
    
}

U4DOpenGLManager::~U4DOpenGLManager(){

    
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
    
    glBindVertexArrayOES(0);
    
}


void U4DOpenGLManager::enableUniformsLocations(){
    
    
    //Model Uniform Location
     modelViewUniformLocations.modelUniformLocation=glGetUniformLocation(shader,"ModelMatrix");  //model matrix
    
    //Model View Uniform Locations
    modelViewUniformLocations.modelViewUniformLocation=glGetUniformLocation(shader,"MVMatrix");  //model-view matrix
    
    modelViewUniformLocations.modelViewProjectionUniformLocation=glGetUniformLocation(shader,"MVPMatrix"); //model-view-projection matrix
    
    modelViewUniformLocations.normaMatrixViewlUniformLocation=glGetUniformLocation(shader, "NormalMatrix"); //normal matrix

    //set up shadow uniform location
    modelViewUniformLocations.depthModelViewProjectionLocation=glGetUniformLocation(shader, "LightSpaceMatrix");
    
    //Texture Uniform Locations
    textureUniformLocations.hasTextureUniformLocation=glGetUniformLocation(shader, "HasTexture");
    textureUniformLocations.emissionTextureUniformLocation=glGetUniformLocation(shader, "EmissionTexture");
    textureUniformLocations.ambientTextureUniformLocation=glGetUniformLocation(shader, "AmbientTexture");
    textureUniformLocations.diffuseTextureUniformLocation=glGetUniformLocation(shader, "DiffuseTexture");
    textureUniformLocations.specularTextureUniformLocation=glGetUniformLocation(shader, "SpecularTexture");
    textureUniformLocations.normalBumpTextureUniformLocation=glGetUniformLocation(shader, "NormalBumpTexture");
    textureUniformLocations.shadowMapTextureUniformLocation=glGetUniformLocation(shader, "ShadowMap");
    
    //Material Uniform Locations
    materialUniformLocations.emissionColorMaterialUniformLocation=glGetUniformLocation(shader, "EmissionMaterialColor");
    materialUniformLocations.ambientColorMaterialUniformLocation=glGetUniformLocation(shader, "AmbientMaterialColor");
    materialUniformLocations.diffuseColorMaterialUniformLocation=glGetUniformLocation(shader, "DiffuseMaterialColor");
    materialUniformLocations.specularColorMaterialUniformLocation=glGetUniformLocation(shader, "SpecularMaterialColor");
    materialUniformLocations.shininessColorMaterialUniformLocation=glGetUniformLocation(shader, "Shininess");
    
    //Animations Uniform Locations
    armatureUniformLocations.boneMatrixUniformLocation=glGetUniformLocation(shader, "BoneMatrix");
    
    //set up the light position uniform
    lightUniformLocations.lightPositionUniformLocation=glGetUniformLocation(shader, "PointLight");
    
    
    //shadow current pass uniform
    lightUniformLocations.shadowCurrentPassUniformLocation=glGetUniformLocation(shader, "ShadowCurrentPass");
    
    //light MVP uniform location
    lightUniformLocations.lightModelViewProjectionUniformLocation=glGetUniformLocation(shader, "LightMVP");
    
}

void U4DOpenGLManager::addCustomUniforms(CustomUniforms uCustomUniforms){
    
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


U4DMatrix4n U4DOpenGLManager::getCameraProjection(){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    
    return camera->getCameraProjectionView();
}

U4DDualQuaternion U4DOpenGLManager::getCameraOrientation(){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    U4DDualQuaternion cameraQuaternion;
    cameraQuaternion=camera->getLocalSpace();
    
    return cameraQuaternion;
}


#pragma mark-draw
void U4DOpenGLManager::draw(){
    
    
    glUseProgram(shader);
    
    glBindVertexArrayOES(vertexObjectArray);
    
    loadMaterialsUniforms();
    
    activateTexturesUniforms();

    U4DDualQuaternion mModel=getEntitySpace();
    
    U4DDualQuaternion mModelWorldView=mModel*getCameraOrientation();
    
    U4DMatrix4n mModelViewMatrix=mModelWorldView.transformDualQuaternionToMatrix4n();
    
    //extract the 3x3 matrix
    U4DMatrix3n modelViewMatrix3x3=mModelViewMatrix.extract3x3Matrix();
    
    //Normal Matrix=get the inverse and transpose it
    
    U4DMatrix3n normalModelViewMatrix;
    
    modelViewMatrix3x3.invert();
    
    normalModelViewMatrix=modelViewMatrix3x3.transpose();
    
    U4DMatrix4n mModelViewProjection;
    
    //get the camera matrix
    
    mModelViewProjection=getCameraProjection()*mModelViewMatrix;
    
    U4DMatrix4n mModelMatrix=mModel.transformDualQuaternionToMatrix4n();
    
    glUniformMatrix4fv(modelViewUniformLocations.modelUniformLocation,1,0,mModelMatrix.matrixData);
    
    glUniformMatrix4fv(modelViewUniformLocations.modelViewUniformLocation,1,0,mModelViewMatrix.matrixData);
    
    glUniformMatrix4fv(modelViewUniformLocations.modelViewProjectionUniformLocation,1,0,mModelViewProjection.matrixData);
    
    glUniformMatrix3fv(modelViewUniformLocations.normaMatrixViewlUniformLocation,1,0,normalModelViewMatrix.matrixData);
    
    glUniform1f(lightUniformLocations.shadowCurrentPassUniformLocation, 1.0);
    
    loadDepthShadowUniform();
    
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
    
    glBindVertexArrayOES(0);
    //I should delete the buffer  glDeleteBuffers
    
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

}

