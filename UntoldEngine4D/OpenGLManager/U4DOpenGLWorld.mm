//
//  U4DOpenGLWorld.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/13/15.
//  Copyright (c) 2015 Untold Story Studio. All rights reserved.
//

#include "U4DOpenGLWorld.h"
#include "U4DWorld.h"
#include "U4DDirector.h"
#include "U4DCamera.h"
#include "U4DLights.h"
#include "Constants.h"
#include "U4DLogger.h"

namespace U4DEngine {
    
U4DOpenGLWorld::U4DOpenGLWorld(U4DWorld *uWorld){
    
    u4dWorld=uWorld;
    
}

U4DOpenGLWorld::~U4DOpenGLWorld(){

    glDeleteFramebuffers(1, &offscreenFramebuffer);
}
    
U4DDualQuaternion U4DOpenGLWorld::getEntitySpace(){
    
    return u4dWorld->getLocalSpace();
    
}

void U4DOpenGLWorld::loadVertexObjectBuffer(){
    
    //init OPENGLBUFFERS
    glGenVertexArrays(1,&vertexObjectArray);
    glBindVertexArray(vertexObjectArray);
    
    //load the vertex
    glGenBuffers(1, &vertexObjectBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexObjectBuffer);
    
    glBufferData(GL_ARRAY_BUFFER,sizeof(float)*(3*u4dWorld->bodyCoordinates.verticesContainer.size()), NULL, GL_STATIC_DRAW);
    
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(float)*3*u4dWorld->bodyCoordinates.verticesContainer.size(), &u4dWorld->bodyCoordinates.verticesContainer[0]);
    
    
}

void U4DOpenGLWorld::enableVerticesAttributeLocations(){
    
    attributeLocations.verticesAttributeLocation=glGetAttribLocation(shader,"Vertex");
    
    //position vertex
    glEnableVertexAttribArray(attributeLocations.verticesAttributeLocation);
    glVertexAttribPointer(attributeLocations.verticesAttributeLocation,3,GL_FLOAT,GL_FALSE,0,0);
}

void U4DOpenGLWorld::drawElements(){
    
    glDrawArrays(GL_LINES, 0, (GLsizei)u4dWorld->bodyCoordinates.verticesContainer.size());

}

#pragma mark-set framebuffer for shadow map
void U4DOpenGLWorld::initShadowMapFramebuffer(){
    
    U4DLogger *logger=U4DLogger::sharedInstance();
    
    //Create Framebuffer here
    glGenFramebuffers(1, &offscreenFramebuffer);
    
    
    //create the destination texture
    glActiveTexture(GL_TEXTURE5);
    glGenTextures(1, &textureID[5]);
    glBindTexture(GL_TEXTURE_2D, textureID[5]);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glTexImage2D(GL_TEXTURE_2D, 0,GL_DEPTH_COMPONENT16, U4DEngine::depthShadowWidth, U4DEngine::depthShadowHeight, 0,GL_DEPTH_COMPONENT, GL_UNSIGNED_INT, NULL);
    
    glBindFramebuffer(GL_FRAMEBUFFER, offscreenFramebuffer);
    
    //attach texture to framebuffer
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D,textureID[5],0);
    
    //enable polygon offset for self-shadowing fix
    glEnable(GL_POLYGON_OFFSET_FILL);
    glPolygonOffset(1.5f, 1.5f);
    
    //check the status of the framebuffer
    
    GLenum fboStatus=glCheckFramebufferStatus(GL_FRAMEBUFFER);
    
    if (fboStatus!=GL_FRAMEBUFFER_COMPLETE) {
        
        switch (fboStatus) {
                
            case GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT:
                
                logger->log("Error: The framebuffer is incomplete attachment.");
                
                break;
                
            case GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT:
                
                logger->log("Error: The framebuffer is missing attachment.");
                
                break;
                
            default:
                
                logger->log("Error: There is an error with the framebuffer, but was not able to detect why.");
                
                break;
        }
    }else{
        
        logger->log("Success: The framebuffer has been set properly for Shadow effects.");
        
    }
    
    //reset framebuffer
    //glBindFramebuffer(GL_FRAMEBUFFER, 2);
}

#pragma mark-Shadow Map Render
void U4DOpenGLWorld::startShadowMapPass(){
    
    //set framebuffer for shadow mapping
    glViewport(0,0,U4DEngine::depthShadowWidth,U4DEngine::depthShadowHeight);
    glBindFramebuffer(GL_FRAMEBUFFER, offscreenFramebuffer);
    glClear(GL_DEPTH_BUFFER_BIT);
    glCullFace(GL_FRONT);
}

void U4DOpenGLWorld::endShadowMapPass(){
    
    glCullFace(GL_BACK);
    //reset framebuffer
    glBindFramebuffer(GL_FRAMEBUFFER, 2);
    glViewport(0,0,displayWidth,displayHeight);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE5);
    glBindTexture(GL_TEXTURE_2D, textureID[5]);
    glUniform1i(textureUniformLocations.shadowMapTextureUniformLocation, 5);
    
    
}

}
