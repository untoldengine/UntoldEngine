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
    
U4DOpenGLDebugger::U4DOpenGLDebugger(U4DDebugger *uDebugger){
    
    u4dDebugger=uDebugger;
    
}

U4DOpenGLDebugger::~U4DOpenGLDebugger(){

}
    
void U4DOpenGLDebugger::draw(){
    
    glUseProgram(shader);
    
    glBindVertexArray(vertexObjectArray);
    
    for (int i=0; i<u4dDebugger->entityContainer.size(); i++) {
     
        U4DEntity *mEntity=u4dDebugger->entityContainer.at(i);
        
        U4DDualQuaternion mModel=mEntity->getAbsoluteSpace();
        
        U4DMatrix4n mModelMatrix=mModel.transformDualQuaternionToMatrix4n();
        
        //get camera matrix
        U4DMatrix4n cameraMatrix=getCameraSpace().transformDualQuaternionToMatrix4n();
        
        cameraMatrix.invert();
        
        U4DMatrix4n mModelViewMatrix=cameraMatrix*mModelMatrix;
        
        U4DMatrix4n mModelViewProjection;
        
        //get the camera matrix
        
        mModelViewProjection=getCameraPerspectiveView()*mModelViewMatrix;
        
        glUniformMatrix4fv(modelViewUniformLocations.modelViewProjectionUniformLocation,1,0,mModelViewProjection.matrixData);
        
        //draw elements
        drawElements();
        
    }
    
    glBindVertexArray(0);
    
    
    
}

void U4DOpenGLDebugger::loadVertexObjectBuffer(){
    
    //init OPENGLBUFFERS
    glGenVertexArrays(1,&vertexObjectArray);
    glBindVertexArray(vertexObjectArray);
    
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
