//
//  U4DOpenGLImage.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DOpenGLImage.h"
#include "U4DDirector.h"
#include "U4DCamera.h"
#include "U4DImage.h"

namespace U4DEngine {
    
U4DOpenGLImage::U4DOpenGLImage(U4DImage *uU4DImage){
    
    u4dObject=uU4DImage;
    
}

U4DOpenGLImage::~U4DOpenGLImage(){

}
    
U4DDualQuaternion U4DOpenGLImage::getEntitySpace(){
    return u4dObject->getLocalSpace();
}

void U4DOpenGLImage::loadVertexObjectBuffer(){
    
    
    //init OPENGLBUFFERS
    glGenVertexArrays(1,&vertexObjectArray);
    glBindVertexArray(vertexObjectArray);
    
    //load the vertex
    glGenBuffers(1, &vertexObjectBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexObjectBuffer);
    
    glBufferData(GL_ARRAY_BUFFER,sizeof(float)*(3*u4dObject->bodyCoordinates.verticesContainer.size()+2*u4dObject->bodyCoordinates.uVContainer.size()), NULL, GL_STATIC_DRAW);
    
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(float)*3*u4dObject->bodyCoordinates.verticesContainer.size(), &u4dObject->bodyCoordinates.verticesContainer[0]);
    
    glBufferSubData(GL_ARRAY_BUFFER, sizeof(float)*(3*u4dObject->bodyCoordinates.verticesContainer.size()), sizeof(float)*2*u4dObject->bodyCoordinates.uVContainer.size(), &u4dObject->bodyCoordinates.uVContainer[0]);
    
}

void U4DOpenGLImage::loadTextureObjectBuffer(){
    
    if (!u4dObject->textureInformation.diffuseTexture.empty()) {
        glActiveTexture(GL_TEXTURE2);
        glGenTextures(1, &textureID[2]);
        glBindTexture(GL_TEXTURE_2D, textureID[2]);
        loadPNGTexture(u4dObject->textureInformation.diffuseTexture, GL_LINEAR, GL_LINEAR, GL_CLAMP_TO_EDGE);
        
    }
    
    
}

void U4DOpenGLImage::enableVerticesAttributeLocations(){
    
    attributeLocations.verticesAttributeLocation=glGetAttribLocation(shader,"Vertex");
    attributeLocations.uvAttributeLocation=glGetAttribLocation(shader, "TextureCoord");
    
    //position vertex
    
    glEnableVertexAttribArray(attributeLocations.verticesAttributeLocation);
    glVertexAttribPointer(attributeLocations.verticesAttributeLocation,3,GL_FLOAT,GL_FALSE,0,0);
    
    //texture vertex
    glEnableVertexAttribArray(attributeLocations.uvAttributeLocation);
    glVertexAttribPointer(attributeLocations.uvAttributeLocation, 2, GL_FLOAT, GL_FALSE, 0, (const GLvoid*)(sizeof(float)*(3*u4dObject->bodyCoordinates.verticesContainer.size())));
    
    
}

U4DMatrix4n U4DOpenGLImage::getCameraPerspectiveView(){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    
    return camera->getCameraOrthographicView();
}

void U4DOpenGLImage::drawElements(){
    
    glDrawElements(GL_TRIANGLES,3*u4dObject->bodyCoordinates.indexContainer.size(),GL_UNSIGNED_INT,&u4dObject->bodyCoordinates.indexContainer[0]);
    
    glDisable(GL_BLEND);
    glEnable(GL_DEPTH_TEST);
}

U4DDualQuaternion U4DOpenGLImage::getCameraSpace(){
    
    U4DDualQuaternion cameraQuaternion;  //IDENTITY MATRIX
    return cameraQuaternion;
}

void U4DOpenGLImage::activateTexturesUniforms(){
   
    glEnable(GL_BLEND);
    glDisable(GL_DEPTH_TEST);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, textureID[2]);
    glUniform1i(textureUniformLocations.diffuseTextureUniformLocation, 2);
    
}

void U4DOpenGLImage::setDiffuseTexture(const char* uTexture){
    
    u4dObject->textureInformation.diffuseTexture=uTexture;
    
}

void U4DOpenGLImage::setImageDimension(float uWidth,float uHeight){
    
    U4DDirector *director=U4DDirector::sharedInstance();
    
    //make a rectangle
    float width=uWidth/director->getDisplayWidth();
    float height=uHeight/director->getDisplayHeight();
    float depth=0.0;
    
    //vertices
    U4DVector3n v1(width,height,depth);
    U4DVector3n v4(width,-height,depth);
    U4DVector3n v2(-width,-height,depth);
    U4DVector3n v3(-width,height,depth);
    
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v1);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v4);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v2);
    u4dObject->bodyCoordinates.addVerticesDataToContainer(v3);
    
    
    //texture
    U4DVector2n t4(0.0,0.0);  //top left
    U4DVector2n t1(1.0,0.0);  //top right
    U4DVector2n t3(0.0,1.0);  //bottom left
    U4DVector2n t2(1.0,1.0);  //bottom right
    
    u4dObject->bodyCoordinates.addUVDataToContainer(t1);
    u4dObject->bodyCoordinates.addUVDataToContainer(t2);
    u4dObject->bodyCoordinates.addUVDataToContainer(t3);
    u4dObject->bodyCoordinates.addUVDataToContainer(t4);
    
    
    U4DIndex i1(0,1,2);
    U4DIndex i2(2,3,0);
    
    
    u4dObject->bodyCoordinates.addIndexDataToContainer(i1);
    u4dObject->bodyCoordinates.addIndexDataToContainer(i2);

    
    
}
    
}

