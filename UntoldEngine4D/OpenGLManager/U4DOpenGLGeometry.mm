//
//  U4DOpenGLGeometry.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DOpenGLGeometry.h"
#include "U4DBoundingVolume.h"

namespace U4DEngine {
    
U4DDualQuaternion U4DOpenGLGeometry::getEntitySpace(){
    
    return u4dObject->getAbsoluteSpace();
    
}

U4DDualQuaternion U4DOpenGLGeometry::getEntityLocalSpace(){
    
    return u4dObject->getLocalSpace();
    
}

U4DVector3n U4DOpenGLGeometry::getEntityAbsolutePosition(){
    
    
    return u4dObject->getAbsolutePosition();
    
}

U4DVector3n U4DOpenGLGeometry::getEntityLocalPosition(){
    
    return u4dObject->getLocalPosition();
    
}

void U4DOpenGLGeometry::loadVertexObjectBuffer(){
    
    //init OPENGLBUFFERS
    glGenVertexArraysOES(1,&vertexObjectArray);
    glBindVertexArrayOES(vertexObjectArray);
    
    //load the vertex
    glGenBuffers(1, &vertexObjectBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexObjectBuffer);
    
    glBufferData(GL_ARRAY_BUFFER,sizeof(float)*(3*u4dObject->bodyCoordinates.verticesContainer.size()), NULL, GL_STATIC_DRAW);
    
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(float)*3*u4dObject->bodyCoordinates.verticesContainer.size(), &u4dObject->bodyCoordinates.verticesContainer[0]);
    
    //load the index into index buffer
    
    GLuint elementBuffer;
    
    glGenBuffers(1, &elementBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, elementBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(int)*3*u4dObject->bodyCoordinates.indexContainer.size(), &u4dObject->bodyCoordinates.indexContainer[0], GL_STATIC_DRAW);
    
}

void U4DOpenGLGeometry::enableVerticesAttributeLocations(){
    
    attributeLocations.verticesAttributeLocation=glGetAttribLocation(shader,"Vertex");
    
    //position vertex
    glEnableVertexAttribArray(attributeLocations.verticesAttributeLocation);
    glVertexAttribPointer(attributeLocations.verticesAttributeLocation,3,GL_FLOAT,GL_FALSE,0,(const GLvoid*)(0));
    
}


void U4DOpenGLGeometry::drawElements(){

    glDrawElements(GL_LINE_LOOP,3*u4dObject->bodyCoordinates.indexContainer.size(),GL_UNSIGNED_INT,(void*)0);

}

}

