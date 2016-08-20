//
//  U4DOpenGLMultiImage.mm
//  UntoldEngine
//
//  Created by Harold Serrano on 6/28/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#include "U4DOpenGLMultiImage.h"
#include "U4DImage.h"

namespace U4DEngine {
    
U4DOpenGLMultiImage::U4DOpenGLMultiImage(U4DImage *uU4DImage):U4DOpenGLImage(uU4DImage),activateMultiTextureImage(FALSE){

}
    
U4DOpenGLMultiImage::~U4DOpenGLMultiImage(){
    
}

void U4DOpenGLMultiImage::setAmbientTexture(const char* uTexture){
    
    u4dObject->textureInformation.ambientTexture=uTexture;
    
}

void U4DOpenGLMultiImage::loadTextureObjectBuffer(){
    
    
    if (!u4dObject->textureInformation.ambientTexture.empty()) {
        glActiveTexture(GL_TEXTURE1);
        glGenTextures(1, &textureID[1]);
        glBindTexture(GL_TEXTURE_2D, textureID[1]);
        loadPNGTexture(u4dObject->textureInformation.ambientTexture, GL_LINEAR, GL_LINEAR, GL_CLAMP_TO_EDGE);
        
    }
    
    if (!u4dObject->textureInformation.diffuseTexture.empty()) {
        glActiveTexture(GL_TEXTURE2);
        glGenTextures(1, &textureID[2]);
        glBindTexture(GL_TEXTURE_2D, textureID[2]);
        loadPNGTexture(u4dObject->textureInformation.diffuseTexture, GL_LINEAR, GL_LINEAR, GL_CLAMP_TO_EDGE);
        
    }
    
    
}

void U4DOpenGLMultiImage::activateTexturesUniforms(){
    
    glEnable(GL_BLEND);
    glDisable(GL_DEPTH_TEST);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, textureID[1]);
    glUniform1i(textureUniformLocations.ambientTextureUniformLocation, 1);
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, textureID[2]);
    glUniform1i(textureUniformLocations.diffuseTextureUniformLocation, 2);
    
}

void U4DOpenGLMultiImage::setMultiImageActiveImage(bool value){
    
    activateMultiTextureImage=value;
}

}