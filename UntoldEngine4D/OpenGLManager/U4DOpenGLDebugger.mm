//
//  U4DOpenGLDebugger.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/24/15.
//  Copyright (c) 2015 Untold Story Studio. All rights reserved.
//

#include "U4DOpenGLDebugger.h"
#include "U4DDebugger.h"
#include "U4DEntity.h"

namespace U4DEngine {
    
void U4DOpenGLDebugger::draw(){
    
    glUseProgram(shader);
    
    glBindVertexArrayOES(vertexObjectArray);
    
    for (int i=0; i<u4dDebugger->entityContainer.size(); i++) {
     
        U4DEntity *mEntity=u4dDebugger->entityContainer.at(i);
        
        U4DDualQuaternion mModel=mEntity->getAbsoluteSpace();
        
        U4DDualQuaternion mModelWorldView=mModel*getCameraSpace();
        
        U4DMatrix4n mModelViewMatrix=mModelWorldView.transformDualQuaternionToMatrix4n();
        
        U4DMatrix4n mModelViewProjection;
        
        //get the camera matrix
        
        mModelViewProjection=getCameraProjection()*mModelViewMatrix;
        
        glUniformMatrix4fv(modelViewUniformLocations.modelViewProjectionUniformLocation,1,0,mModelViewProjection.matrixData);
        
        //draw elements
        drawElements();
        
    }
    
    glBindVertexArrayOES(0);
    //I should delete the buffer  glDeleteBuffers
    
}

void U4DOpenGLDebugger::loadVertexObjectBuffer(){
    
    //init OPENGLBUFFERS
    glGenVertexArraysOES(1,&vertexObjectArray);
    glBindVertexArrayOES(vertexObjectArray);
    
    //load the vertex
    glGenBuffers(1, &vertexObjectBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexObjectBuffer);
    
    glBufferData(GL_ARRAY_BUFFER,sizeof(float)*(3*u4dDebugger->bodyCoordinates.verticesContainer.size()), NULL, GL_STATIC_DRAW);
    
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(float)*3*u4dDebugger->bodyCoordinates.verticesContainer.size(), &u4dDebugger->bodyCoordinates.verticesContainer[0]);

}

void U4DOpenGLDebugger::enableVerticesAttributeLocations(){
    
    attributeLocations.verticesAttributeLocation=glGetAttribLocation(shader,"Vertex");
    
    //position vertex
    glEnableVertexAttribArray(attributeLocations.verticesAttributeLocation);
    glVertexAttribPointer(attributeLocations.verticesAttributeLocation,3,GL_FLOAT,GL_FALSE,0,0);

}

void U4DOpenGLDebugger::drawElements(){
    
     glDrawArrays(GL_LINES, 0,u4dDebugger->bodyCoordinates.verticesContainer.size());
    
}

}
