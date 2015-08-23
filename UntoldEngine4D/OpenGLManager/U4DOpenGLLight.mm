//
//  U4DOpenGLLight.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/24/15.
//  Copyright (c) 2015 Untold Story Studio. All rights reserved.
//

#include "U4DOpenGLLight.h"
#include "U4DLights.h"

namespace U4DEngine {
    
U4DDualQuaternion U4DOpenGLLight::getEntitySpace(){
    
    return u4dLight->getAbsoluteSpace();
}

void U4DOpenGLLight::loadVertexObjectBuffer(){
    
    //init OPENGLBUFFERS
    glGenVertexArraysOES(1,&vertexObjectArray);
    glBindVertexArrayOES(vertexObjectArray);
    
    //load the vertex
    glGenBuffers(1, &vertexObjectBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexObjectBuffer);
    
    glBufferData(GL_ARRAY_BUFFER,sizeof(float)*(3*u4dLight->bodyCoordinates.verticesContainer.size()), NULL, GL_STATIC_DRAW);
    
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(float)*3*u4dLight->bodyCoordinates.verticesContainer.size(), &u4dLight->bodyCoordinates.verticesContainer[0]);

}

void U4DOpenGLLight::enableVerticesAttributeLocations(){
    
    attributeLocations.verticesAttributeLocation=glGetAttribLocation(shader,"Vertex");
    
    //position vertex
    glEnableVertexAttribArray(attributeLocations.verticesAttributeLocation);
    glVertexAttribPointer(attributeLocations.verticesAttributeLocation,3,GL_FLOAT,GL_FALSE,0,0);

    
}

void U4DOpenGLLight::drawElements(){
    
    glDrawElements(GL_TRIANGLES,3*u4dLight->bodyCoordinates.indexContainer.size(),GL_UNSIGNED_INT,&u4dLight->bodyCoordinates.indexContainer[0]);
    
}

}
