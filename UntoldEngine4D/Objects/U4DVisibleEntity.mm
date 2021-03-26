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

    
    void U4DVisibleEntity::loadRenderingInformation(){
        
        renderEntity->loadRenderingInformation();
        
    }

    U4DRenderEntity *U4DVisibleEntity::getRenderEntity(){
        return renderEntity;
    }

    void U4DVisibleEntity::setPipelineForPass(std::string uPipelineName,int uRenderPassKey){
        renderEntity->setPipelineForPass(uPipelineName, uRenderPassKey);
    }

    void U4DVisibleEntity::setPipeline(std::string uPipelineName){
        renderEntity->setPipelineForPass(uPipelineName, U4DEngine::finalPass);
    }

}



