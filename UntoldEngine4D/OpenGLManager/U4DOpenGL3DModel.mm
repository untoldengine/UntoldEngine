//
//  U4DOpenGL3DModel.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DOpenGL3DModel.h"
#include "U4DDirector.h"
#include "Constants.h"
#include "U4DCamera.h"
#include "U4DLights.h"
#include "U4DMatrix4n.h"
#include "U4DModel.h"
#include "U4DDualQuaternion.h"

namespace U4DEngine {
    
U4DOpenGL3DModel::U4DOpenGL3DModel(U4DModel *uU4DModel){
    
    u4dObject=uU4DModel;
}


U4DOpenGL3DModel::~U4DOpenGL3DModel(){
    //delete the element index buffer
    glDeleteBuffers(1, &elementBuffer);
}
    
U4DDualQuaternion U4DOpenGL3DModel::getEntitySpace(){
    
    return u4dObject->getAbsoluteSpace();
    
}

U4DDualQuaternion U4DOpenGL3DModel::getEntityLocalSpace(){
    
    return u4dObject->getLocalSpace();
    
}

U4DVector3n U4DOpenGL3DModel::getEntityAbsolutePosition(){
    
    
    return u4dObject->getAbsolutePosition();
    
}

U4DVector3n U4DOpenGL3DModel::getEntityLocalPosition(){
    
    return u4dObject->getLocalPosition();
    
}


void U4DOpenGL3DModel::loadVertexObjectBuffer(){
    
    
    //init OPENGLBUFFERS
    glGenVertexArrays(1,&vertexObjectArray);
    glBindVertexArray(vertexObjectArray);
    
    //load the vertex
    glGenBuffers(1, &vertexObjectBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexObjectBuffer);
    
    glBufferData(GL_ARRAY_BUFFER,sizeof(float)*(3*u4dObject->bodyCoordinates.verticesContainer.size()+3*u4dObject->bodyCoordinates.normalContainer.size()+2*u4dObject->bodyCoordinates.uVContainer.size()+4*u4dObject->bodyCoordinates.tangentContainer.size()+4*u4dObject->bodyCoordinates.vertexWeightsContainer.size()+4*u4dObject->bodyCoordinates.boneIndicesContainer.size()+u4dObject->materialInformation.materialIndexColorContainer.size()), NULL, GL_STATIC_DRAW);
    
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(float)*3*u4dObject->bodyCoordinates.verticesContainer.size(), &u4dObject->bodyCoordinates.verticesContainer[0]);
    
    
    glBufferSubData(GL_ARRAY_BUFFER, sizeof(float)*3*u4dObject->bodyCoordinates.verticesContainer.size(), sizeof(float)*3*u4dObject->bodyCoordinates.normalContainer.size(), &u4dObject->bodyCoordinates.normalContainer[0]);
    
    glBufferSubData(GL_ARRAY_BUFFER, sizeof(float)*(3*u4dObject->bodyCoordinates.verticesContainer.size()+3*u4dObject->bodyCoordinates.normalContainer.size()), sizeof(float)*2*u4dObject->bodyCoordinates.uVContainer.size(), &u4dObject->bodyCoordinates.uVContainer[0]);
    
    glBufferSubData(GL_ARRAY_BUFFER, sizeof(float)*(3*u4dObject->bodyCoordinates.verticesContainer.size()+3*u4dObject->bodyCoordinates.normalContainer.size()+2*u4dObject->bodyCoordinates.uVContainer.size()), sizeof(float)*4*u4dObject->bodyCoordinates.tangentContainer.size(), &u4dObject->bodyCoordinates.tangentContainer[0]);
    
    //load vertex weights container
    glBufferSubData(GL_ARRAY_BUFFER, sizeof(float)*(3*u4dObject->bodyCoordinates.verticesContainer.size()+3*u4dObject->bodyCoordinates.normalContainer.size()+2*u4dObject->bodyCoordinates.uVContainer.size()+4*u4dObject->bodyCoordinates.tangentContainer.size()), sizeof(float)*4*u4dObject->bodyCoordinates.vertexWeightsContainer.size(), &u4dObject->bodyCoordinates.vertexWeightsContainer[0]);
    
    //load bone indices container
    glBufferSubData(GL_ARRAY_BUFFER, sizeof(float)*(3*u4dObject->bodyCoordinates.verticesContainer.size()+3*u4dObject->bodyCoordinates.normalContainer.size()+2*u4dObject->bodyCoordinates.uVContainer.size()+4*u4dObject->bodyCoordinates.tangentContainer.size()+4*u4dObject->bodyCoordinates.vertexWeightsContainer.size()), sizeof(float)*4*u4dObject->bodyCoordinates.boneIndicesContainer.size(), &u4dObject->bodyCoordinates.boneIndicesContainer[0]);
    
    //load material index container
    glBufferSubData(GL_ARRAY_BUFFER, sizeof(float)*(3*u4dObject->bodyCoordinates.verticesContainer.size()+3*u4dObject->bodyCoordinates.normalContainer.size()+2*u4dObject->bodyCoordinates.uVContainer.size()+4*u4dObject->bodyCoordinates.tangentContainer.size()+4*u4dObject->bodyCoordinates.vertexWeightsContainer.size()+4*u4dObject->bodyCoordinates.boneIndicesContainer.size()), sizeof(float)*u4dObject->materialInformation.materialIndexColorContainer.size(), &u4dObject->materialInformation.materialIndexColorContainer[0]);

    
    //load the index into index buffer
    
    glGenBuffers(1, &elementBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, elementBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(int)*3*u4dObject->bodyCoordinates.indexContainer.size(), &u4dObject->bodyCoordinates.indexContainer[0], GL_STATIC_DRAW);

    //checkErrors(u4dObject->getName(), "Loading Vertex Object Buffer");
    
}

void U4DOpenGL3DModel::loadMaterialsUniforms(){
        
    if (!u4dObject->materialInformation.diffuseMaterialColorContainer.empty()) {
        glUniform4fv(materialUniformLocations.diffuseColorMaterialUniformLocation, (GLsizei)u4dObject->materialInformation.diffuseMaterialColorContainer.size(), u4dObject->materialInformation.diffuseMaterialColorContainer[0].colorData);
    }
    
    if (!u4dObject->materialInformation.specularMaterialColorContainer.empty()) {
        glUniform4fv(materialUniformLocations.specularColorMaterialUniformLocation, (GLsizei)u4dObject->materialInformation.specularMaterialColorContainer.size(), u4dObject->materialInformation.specularMaterialColorContainer[0].colorData);
    }
    
    if (!u4dObject->materialInformation.diffuseMaterialIntensityContainer.empty()) {
        glUniform1fv(materialUniformLocations.diffuseIntensityMaterialUniformLocation, (GLsizei)u4dObject->materialInformation.diffuseMaterialIntensityContainer.size(), &u4dObject->materialInformation.diffuseMaterialIntensityContainer[0]);
    }
    
    if (!u4dObject->materialInformation.specularMaterialIntensityContainer.empty()) {
        glUniform1fv(materialUniformLocations.specularIntensityMaterialUniformLocation, (GLsizei)u4dObject->materialInformation.specularMaterialIntensityContainer.size(), &u4dObject->materialInformation.specularMaterialIntensityContainer[0]);
    }
    
    if (!u4dObject->materialInformation.specularMaterialHardnessContainer.empty()) {
        glUniform1fv(materialUniformLocations.specularHardnessMaterialUniformLocation, (GLsizei)u4dObject->materialInformation.specularMaterialHardnessContainer.size(), &u4dObject->materialInformation.specularMaterialHardnessContainer[0]);
    }

    //checkErrors(u4dObject->getName(), "Loading Materials Uniform");
    
}

void U4DOpenGL3DModel::loadTextureObjectBuffer(){
    
    
        if (!u4dObject->textureInformation.emissionTexture.empty()) {
            
            glActiveTexture(GL_TEXTURE0);
            glGenTextures(1, &textureID[0]);
            glBindTexture(GL_TEXTURE_2D, textureID[0]);
            loadPNGTexture(u4dObject->textureInformation.emissionTexture, GL_LINEAR, GL_LINEAR, GL_CLAMP_TO_EDGE);
            
        }
        
        
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
        
        if (!u4dObject->textureInformation.specularTexture.empty()) {
            glActiveTexture(GL_TEXTURE3);
            glGenTextures(1, &textureID[3]);
            glBindTexture(GL_TEXTURE_2D, textureID[3]);
            loadPNGTexture(u4dObject->textureInformation.specularTexture, GL_LINEAR, GL_LINEAR, GL_CLAMP_TO_EDGE);
        }
        
        if (!u4dObject->textureInformation.normalBumpTexture.empty()) {
            glActiveTexture(GL_TEXTURE4);
            glGenTextures(1, &textureID[4]);
            glBindTexture(GL_TEXTURE_2D, textureID[4]);
            loadPNGTexture(u4dObject->textureInformation.normalBumpTexture, GL_LINEAR, GL_LINEAR, GL_CLAMP_TO_EDGE);
        }
    
    //checkErrors(u4dObject->getName(), "Loading Texture Object Buffer");
}

void U4DOpenGL3DModel::loadLightsUniforms(){
 
    U4DLights *light=U4DLights::sharedInstance();
    
    U4DVector3n lightPosition=light->getAbsolutePosition();
    
    U4DDualQuaternion lightViewSpace=light->getAbsoluteSpace();
    
    U4DMatrix4n lightMatrix=lightViewSpace.transformDualQuaternionToMatrix4n();
    
    lightPosition=lightMatrix*lightPosition;
    
    //load the light position
    glUniform4f(lightUniformLocations.lightPositionUniformLocation, lightPosition.x, lightPosition.y, lightPosition.z, 1.0);

}



void U4DOpenGL3DModel::enableVerticesAttributeLocations(){
    
    attributeLocations.verticesAttributeLocation=glGetAttribLocation(shader,"Vertex");
    attributeLocations.normalAttributeLocation=glGetAttribLocation(shader,"Normal");
    attributeLocations.uvAttributeLocation=glGetAttribLocation(shader, "TextureCoord");
    attributeLocations.materialIndexAttributeLocation=glGetAttribLocation(shader, "MaterialIndex");
    attributeLocations.tangetVectorAttributeLocation=glGetAttribLocation(shader, "TangentVector");
    attributeLocations.vertexWeightAttributeLocation=glGetAttribLocation(shader, "Weights");
    attributeLocations.boneIndicesAttributeLocation=glGetAttribLocation(shader, "BoneIndices");
    
    //position vertex
    glEnableVertexAttribArray(attributeLocations.verticesAttributeLocation);
    glVertexAttribPointer(attributeLocations.verticesAttributeLocation,3,GL_FLOAT,GL_FALSE,0,(const GLvoid*)(0));
    
    //normal vertex
    glEnableVertexAttribArray(attributeLocations.normalAttributeLocation);
    glVertexAttribPointer(attributeLocations.normalAttributeLocation,3,GL_FLOAT,GL_FALSE,0,(const GLvoid*)(sizeof(float)*3*u4dObject->bodyCoordinates.verticesContainer.size()));
    
    //texture vertex
    glEnableVertexAttribArray(attributeLocations.uvAttributeLocation);
    glVertexAttribPointer(attributeLocations.uvAttributeLocation, 2, GL_FLOAT, GL_FALSE, 0, (const GLvoid*)(sizeof(float)*(3*u4dObject->bodyCoordinates.verticesContainer.size()+3*u4dObject->bodyCoordinates.normalContainer.size())));
    
    //tangent vector vertex
    
    glEnableVertexAttribArray(attributeLocations.tangetVectorAttributeLocation);
    glVertexAttribPointer(attributeLocations.tangetVectorAttributeLocation, 4, GL_FLOAT, GL_FALSE, 0, (const GLvoid*)(sizeof(float)*(3*u4dObject->bodyCoordinates.verticesContainer.size()+3*u4dObject->bodyCoordinates.normalContainer.size()+2*u4dObject->bodyCoordinates.uVContainer.size())));
    
    if (u4dObject->getHasArmature()) {
        //vertex weights
        glEnableVertexAttribArray(attributeLocations.vertexWeightAttributeLocation);
        glVertexAttribPointer(attributeLocations.vertexWeightAttributeLocation, 4, GL_FLOAT, GL_FALSE, 0, (const GLvoid*)(sizeof(float)*(3*u4dObject->bodyCoordinates.verticesContainer.size()+3*u4dObject->bodyCoordinates.normalContainer.size()+2*u4dObject->bodyCoordinates.uVContainer.size()+4*u4dObject->bodyCoordinates.tangentContainer.size())));
        
        //bone indices
        glEnableVertexAttribArray(attributeLocations.boneIndicesAttributeLocation);
        glVertexAttribPointer(attributeLocations.boneIndicesAttributeLocation, 4, GL_FLOAT, GL_FALSE, 0, (const GLvoid*)(sizeof(float)*(3*u4dObject->bodyCoordinates.verticesContainer.size()+3*u4dObject->bodyCoordinates.normalContainer.size()+2*u4dObject->bodyCoordinates.uVContainer.size()+4*u4dObject->bodyCoordinates.tangentContainer.size()+4*u4dObject->bodyCoordinates.vertexWeightsContainer.size())));
    }
    
    //material index
    glEnableVertexAttribArray(attributeLocations.materialIndexAttributeLocation);
    glVertexAttribPointer(attributeLocations.materialIndexAttributeLocation, 1, GL_FLOAT, GL_FALSE, 0, (const GLvoid*)(sizeof(float)*(3*u4dObject->bodyCoordinates.verticesContainer.size()+3*u4dObject->bodyCoordinates.normalContainer.size()+2*u4dObject->bodyCoordinates.uVContainer.size()+4*u4dObject->bodyCoordinates.tangentContainer.size()+4*u4dObject->bodyCoordinates.vertexWeightsContainer.size()+4*u4dObject->bodyCoordinates.boneIndicesContainer.size())));
    
    //checkErrors(u4dObject->getName(), "Enabling Vertices Attributes");
}

void U4DOpenGL3DModel::drawElements(){
    
    glDrawElements(GL_TRIANGLES,3*(GLsizei)u4dObject->bodyCoordinates.indexContainer.size(),GL_UNSIGNED_INT,(void*)0);
    
}

void U4DOpenGL3DModel::activateTexturesUniforms(){
    
    
        if (!u4dObject->textureInformation.emissionTexture.empty()) {
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, textureID[0]);
        glUniform1i(textureUniformLocations.emissionTextureUniformLocation, 0);
        }
        
        if (!u4dObject->textureInformation.ambientTexture.empty()) {
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, textureID[1]);
        glUniform1i(textureUniformLocations.ambientTextureUniformLocation, 1);
        }
        
        if (!u4dObject->textureInformation.diffuseTexture.empty()) {
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, textureID[2]);
        glUniform1i(textureUniformLocations.diffuseTextureUniformLocation, 2);
        }
        
        if (!u4dObject->textureInformation.specularTexture.empty()) {
        glActiveTexture(GL_TEXTURE3);
        glBindTexture(GL_TEXTURE_2D, textureID[3]);
        glUniform1i(textureUniformLocations.specularTextureUniformLocation, 3);
        }
        
        if (!u4dObject->textureInformation.normalBumpTexture.empty()) {
        glActiveTexture(GL_TEXTURE4);
        glBindTexture(GL_TEXTURE_2D, textureID[4]);
        glUniform1i(textureUniformLocations.normalBumpTextureUniformLocation, 4);
        }
    
    //checkErrors(u4dObject->getName(), "Loading Texture Uniforms");
    
}

void U4DOpenGL3DModel::setNormalBumpTexture(const char* uTexture){
    
    u4dObject->textureInformation.normalBumpTexture=uTexture;
    
}

void U4DOpenGL3DModel::loadArmatureUniforms(){
    
    if (u4dObject->getHasArmature()) {
        
        //send HasArmature to shaders
        glUniform1f(armatureUniformLocations.hasArmatureUniformLocation, 1.0);
        
        //load the final space transform
        glUniformMatrix4fv(armatureUniformLocations.boneMatrixUniformLocation, (GLsizei)u4dObject->armatureManager->boneDataContainer.size(), 0, u4dObject->armatureBoneMatrix[0].matrixData);
        
    }else{
        
        glUniform1f(armatureUniformLocations.hasArmatureUniformLocation, 0.0);
        
    }
    
    
}

void U4DOpenGL3DModel::drawDepthOnFrameBuffer(){
    
    glEnable(GL_DEPTH_TEST);
    
    glUseProgram(shader);
    
    glBindVertexArray(vertexObjectArray);
    
    //compute ortho space
    U4DMatrix4n depthOrthoMatrix;
    
    depthOrthoMatrix.computeOrthographicMatrix(-300.0, 300.0, -150.0, 150.0, -250.0f, 250.0f);
    
    U4DLights *light=U4DLights::sharedInstance();
    
    //get light absolute space
    U4DDualQuaternion lightViewSpace=light->getAbsoluteSpace();
    
    U4DMatrix4n lightMatrix=lightViewSpace.transformDualQuaternionToMatrix4n();
    
    //light space matrix
    lightSpaceMatrix=depthOrthoMatrix*lightMatrix;
    
    //get model absolute space
    U4DDualQuaternion mModel=getEntitySpace();
    
    U4DMatrix4n mModelMatrix=mModel.transformDualQuaternionToMatrix4n();
    
    //load depth shader uniform
    glUniformMatrix4fv(lightUniformLocations.lightShadowDepthUniformLocation,1,0,lightSpaceMatrix.matrixData);
    
    //load model matrix
    glUniformMatrix4fv(modelViewUniformLocations.modelUniformLocation,1,0,mModelMatrix.matrixData);
    
    //load the shadow current pass
    glUniform1f(lightUniformLocations.shadowCurrentPassUniformLocation, 0.0);
    
    //load armature uniform
    loadArmatureUniforms();
    
    //draw elements
    drawElements();
    
    glBindVertexArray(0);
    
    glUseProgram(shader);
}

void U4DOpenGL3DModel::loadDepthShadowUniform(){
    
    glUniformMatrix4fv(lightUniformLocations.lightShadowDepthUniformLocation,1,0,lightSpaceMatrix.matrixData);
    
}
    
void U4DOpenGL3DModel::loadSelfShadowBiasUniform(){
    
    float selfShadowBias=u4dObject->getSelfShadowBias();
    
    glUniform1f(textureUniformLocations.selfShadowBiasUniformLocation,selfShadowBias);
    
}
    
void U4DOpenGL3DModel::loadHasTextureUniform(){
    
    if (u4dObject->getHasTexture()) {
        
        glUniform1f(textureUniformLocations.hasTextureUniformLocation, 1.0);
    }else{
        glUniform1f(textureUniformLocations.hasTextureUniformLocation, 0.0);
    }
    
}

}


