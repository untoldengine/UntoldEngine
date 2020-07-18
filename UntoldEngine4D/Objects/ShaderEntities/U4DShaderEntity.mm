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

U4DShaderEntity::U4DShaderEntity():shaderParameterContainer(24,U4DVector4n(0.0,0.0,0.0,0.0)){
        
        renderManager=new U4DRenderShaderEntity(this);
        
    }

    U4DShaderEntity::~U4DShaderEntity(){
        
        delete renderManager;
        
    }

    void U4DShaderEntity::setTexture0(const char* uTexture0){
        
        renderManager->setDiffuseTexture(uTexture0);
    
    }
    

    void U4DShaderEntity::setShaderDimension(float uWidth,float uHeight){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        //make a rectangle
        float width=uWidth/director->getDisplayWidth();
        float height=uHeight/director->getDisplayHeight();
        float depth=0.0;
        
        //vertices
        U4DEngine::U4DVector3n v1(width,height,depth);
        U4DEngine::U4DVector3n v4(width,-height,depth);
        U4DEngine::U4DVector3n v2(-width,-height,depth);
        U4DEngine::U4DVector3n v3(-width,height,depth);
        
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

    void U4DShaderEntity::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        renderManager->render(uRenderEncoder);
        
    }

    std::vector<U4DVector4n> U4DShaderEntity::getShaderParameterContainer(){
        
        return shaderParameterContainer;
    }

    void U4DShaderEntity::updateShaderParameterContainer(int uPosition, U4DVector4n &uParamater){
     
        if (uPosition<shaderParameterContainer.size()) {
            
            shaderParameterContainer.at(uPosition)=uParamater;
            
        }
    
    }

}
