//
//  U4DVisibleEntity.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DVisibleEntity.h"

namespace U4DEngine {
    
    U4DVisibleEntity::U4DVisibleEntity(){
        
    }

    U4DVisibleEntity::U4DVisibleEntity(const U4DVisibleEntity& value){

    }

    U4DVisibleEntity& U4DVisibleEntity::operator=(const U4DVisibleEntity& value){
        
        return *this;
    }

    
    void U4DVisibleEntity::setShader(std::string uVertexShaderName, std::string uFragmentShaderName){
        
        vertexShader=uVertexShaderName;
        fragmentShader=uFragmentShaderName;
        
    }
    
    void U4DVisibleEntity::setOffscreenShader(std::string uVertexShaderName, std::string uFragmentShaderName){
    
        offscreenVertexShader=uVertexShaderName;
        offscreenFragmentShader=uFragmentShaderName;
        
    }
    
    std::string U4DVisibleEntity::getVertexShader(){
        
        return vertexShader;
    }
    
    std::string U4DVisibleEntity::getFragmentShader(){
        return fragmentShader;
    }

    std::string U4DVisibleEntity::getVertexOffscreenShader(){
        return offscreenVertexShader;
    }
    std::string U4DVisibleEntity::getFragmentOffscreenShader(){
        return offscreenFragmentShader;
    }
    
    void U4DVisibleEntity::loadRenderingInformation(){
        
        renderManager->loadRenderingInformation();
        
    }


}



