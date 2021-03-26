//
//  U4DShaderEntity.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/7/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DShaderEntity.h"
#include "U4DRenderShaderEntity.h"
#include "U4DDirector.h"

namespace U4DEngine {

U4DShaderEntity::U4DShaderEntity(int uParamSize):shaderParameterContainer(uParamSize,U4DVector4n(0.0,0.0,0.0,0.0)),enableBlending(true),enableAdditiveRendering(true){
        
        renderEntity=new U4DRenderShaderEntity(this);
        
    }

    U4DShaderEntity::~U4DShaderEntity(){
        
        delete renderEntity;
        
    }

    void U4DShaderEntity::setTexture0(const char* uTexture0){
        
        textureInformation.texture0=uTexture0;
    
    }


    void U4DShaderEntity::setTexture1(const char* uTexture1){
        
        textureInformation.texture1=uTexture1;

    }
    

    void U4DShaderEntity::setShaderDimension(float uWidth,float uHeight){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        //make a rectangle
        shaderWidth=uWidth/director->getDisplayWidth();
        shaderHeight=uHeight/director->getDisplayHeight();
        float depth=0.0;
        
        //vertices
        U4DEngine::U4DVector3n v1(shaderWidth,shaderHeight,depth);
        U4DEngine::U4DVector3n v4(shaderWidth,-shaderHeight,depth);
        U4DEngine::U4DVector3n v2(-shaderWidth,-shaderHeight,depth);
        U4DEngine::U4DVector3n v3(-shaderWidth,shaderHeight,depth);
        
        bodyCoordinates.addVerticesDataToContainer(v1);
        bodyCoordinates.addVerticesDataToContainer(v4);
        bodyCoordinates.addVerticesDataToContainer(v2);
        bodyCoordinates.addVerticesDataToContainer(v3);
        
        
        //texture
        U4DEngine::U4DVector2n t4(0.0,0.0);  //top left
        U4DEngine::U4DVector2n t1(1.0,0.0);  //top right
        U4DEngine::U4DVector2n t3(0.0,1.0);  //bottom left
        U4DEngine::U4DVector2n t2(1.0,1.0);  //bottom right
        
        bodyCoordinates.addUVDataToContainer(t1);
        bodyCoordinates.addUVDataToContainer(t2);
        bodyCoordinates.addUVDataToContainer(t3);
        bodyCoordinates.addUVDataToContainer(t4);
        
        
        U4DEngine::U4DIndex i1(0,1,2);
        U4DEngine::U4DIndex i2(2,3,0);
        
        
        bodyCoordinates.addIndexDataToContainer(i1);
        bodyCoordinates.addIndexDataToContainer(i2);
        
    }

    float U4DShaderEntity::getShaderWidth(){
        
        return shaderWidth;
        
    }
        
    float U4DShaderEntity::getShaderHeight(){
        
        return shaderHeight;
    }

    void U4DShaderEntity::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        renderEntity->render(uRenderEncoder);
        
    }

    void U4DShaderEntity::update(double dt){
        
    }

    std::vector<U4DVector4n> U4DShaderEntity::getShaderParameterContainer(){
        
        return shaderParameterContainer;
    }

    void U4DShaderEntity::updateShaderParameterContainer(int uPosition, U4DVector4n &uParamater){
     
        if (uPosition<shaderParameterContainer.size()) {
            
            shaderParameterContainer.at(uPosition)=uParamater;
            
        }
    
    }

    void U4DShaderEntity::setEnableBlending(bool uValue){
        enableBlending=uValue;
    }

    bool U4DShaderEntity::getEnableBlending(){
        return enableBlending;
    }

    bool U4DShaderEntity::getEnableAdditiveRendering(){
        
        return enableAdditiveRendering;
    }

    void U4DShaderEntity::setEnableAdditiveRendering(bool uValue){
        enableAdditiveRendering=uValue;
    }

    void U4DShaderEntity::setHasTexture(bool uValue){
            hasTexture=uValue;
        }
        
        
    bool U4DShaderEntity::getHasTexture(){
            return hasTexture;
        }

}
