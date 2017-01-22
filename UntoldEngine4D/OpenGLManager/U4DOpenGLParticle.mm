//
//  U4DOpenGLParticle.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/15/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "U4DOpenGLParticle.h"
#include "U4DParticle.h"

namespace U4DEngine {
    
    U4DOpenGLParticle::U4DOpenGLParticle(U4DParticle* uU4DParticle){
        
        u4dObject=uU4DParticle;
        
    }
    
    
    U4DOpenGLParticle::~U4DOpenGLParticle(){
        
    }
    
    U4DDualQuaternion U4DOpenGLParticle::getEntitySpace(){
        
        return u4dObject->getAbsoluteSpace();
        
    }
    
    U4DDualQuaternion U4DOpenGLParticle::getEntityLocalSpace(){
        
        return u4dObject->getLocalSpace();
        
    }
    
    U4DVector3n U4DOpenGLParticle::getEntityAbsolutePosition(){
        
        
        return u4dObject->getAbsolutePosition();
        
    }
    
    U4DVector3n U4DOpenGLParticle::getEntityLocalPosition(){
        
        return u4dObject->getLocalPosition();
        
    }
    
    void U4DOpenGLParticle::enableVerticesAttributeLocations(){
        
        particleAttributeLocations.verticesAttributeLocation=glGetAttribLocation(shader,"Vertex");
        particleAttributeLocations.velocityAttributeLocation=glGetAttribLocation(shader, "Velocity");
        particleAttributeLocations.startTimeAttributeLocation=glGetAttribLocation(shader, "StartTime");
        
        //position vertex
        
        glEnableVertexAttribArray(particleAttributeLocations.verticesAttributeLocation);
        glVertexAttribPointer(particleAttributeLocations.verticesAttributeLocation,3,GL_FLOAT,GL_FALSE,0,0);
        
        //velocity
        glEnableVertexAttribArray(particleAttributeLocations.velocityAttributeLocation);
        glVertexAttribPointer(particleAttributeLocations.velocityAttributeLocation, 3, GL_FLOAT, GL_FALSE, 0, (const GLvoid*)(sizeof(float)*(3*u4dObject->particleCoordinates.verticesContainer.size())));
        
        //start time
        
        glEnableVertexAttribArray(particleAttributeLocations.startTimeAttributeLocation);
        glVertexAttribPointer(particleAttributeLocations.startTimeAttributeLocation, 1, GL_FLOAT, GL_FALSE, 0, (const GLvoid*)(sizeof(float)*(3*u4dObject->particleCoordinates.verticesContainer.size()+3*u4dObject->particleCoordinates.velocityContainer.size())));
        
        
        glVertexAttribDivisor(particleAttributeLocations.velocityAttributeLocation, 1);
        glVertexAttribDivisor(particleAttributeLocations.startTimeAttributeLocation, 1);
    }
    
    void U4DOpenGLParticle::loadVertexObjectBuffer(){
        
        //init OPENGLBUFFERS
        glGenVertexArrays(1,&vertexObjectArray);
        glBindVertexArray(vertexObjectArray);
        
        //load the vertex
        glGenBuffers(1, &vertexObjectBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, vertexObjectBuffer);
        
        glBufferData(GL_ARRAY_BUFFER,sizeof(float)*(3*u4dObject->particleCoordinates.verticesContainer.size()+3*u4dObject->particleCoordinates.velocityContainer.size()+ u4dObject->particleCoordinates.startTimeContainer.size()), NULL, GL_STATIC_DRAW);
        
        //load vertex data
        glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(float)*3*u4dObject->particleCoordinates.verticesContainer.size(), &u4dObject->particleCoordinates.verticesContainer[0]);
        
        //load velocity data
        glBufferSubData(GL_ARRAY_BUFFER, sizeof(float)*(3*u4dObject->particleCoordinates.verticesContainer.size()), sizeof(float)*3*u4dObject->particleCoordinates.velocityContainer.size(), &u4dObject->particleCoordinates.velocityContainer[0]);
        
        //load start time
        glBufferSubData(GL_ARRAY_BUFFER, sizeof(float)*(3*u4dObject->particleCoordinates.verticesContainer.size()+3*u4dObject->particleCoordinates.velocityContainer.size()), sizeof(float)*3*u4dObject->particleCoordinates.startTimeContainer.size(), &u4dObject->particleCoordinates.startTimeContainer[0]);
        
        
    }
    
    void U4DOpenGLParticle::drawElements(){
        
        //glDisable(GL_DEPTH_TEST);
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        
        //glDrawElementsInstanced(GL_POINTS, 3*(GLsizei)u4dObject->particleCoordinates.indexContainer.size(), GL_UNSIGNED_INT, (void*)0, u4dObject->getNumberOfParticles());
        
        glDrawArraysInstanced(GL_POINTS, 0, 3*(GLsizei)u4dObject->particleCoordinates.verticesContainer.size(), u4dObject->getNumberOfParticles());
        //glDrawArrays(GL_POINTS, 0, 3*(GLsizei)u4dObject->particleCoordinates.verticesContainer.size());
        
        glDisable(GL_BLEND);
        //glEnable(GL_DEPTH_TEST);
    }
    
}
