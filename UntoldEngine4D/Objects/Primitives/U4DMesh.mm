//
//  U4DMesh.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/10/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DMesh.h"
#include "U4DCamera.h"
#include "U4DDirector.h"
#include "U4DMatrix4n.h"
#include "U4DMatrix3n.h"
#include <float.h>
#include "U4DRenderGeometry.h"

namespace U4DEngine {
    
    
    U4DMesh::U4DMesh():visibility(false){
        
        setEntityType(PRIMITIVE);
        
        renderEntity=new U4DRenderGeometry(this);
        
        renderEntity->setPipelineForPass("geometrypipeline",U4DEngine::finalPass);
        
    }
    
    
    U4DMesh::~U4DMesh(){
        
        delete renderEntity;
        
    }
    
    
    U4DMesh::U4DMesh(const U4DMesh& value){};
    
    
    U4DMesh& U4DMesh::operator=(const U4DMesh& value){
        
        return *this;
        
    };
    
    void U4DMesh::loadRenderingInformation(){

        renderEntity->loadRenderingInformation();
    }

    void U4DMesh::updateRenderingInformation(){
        
        renderEntity->updateRenderingInformation();
    }

    void U4DMesh::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        if (visibility==true) {
            renderEntity->render(uRenderEncoder);
        }
        
    }
    
    void U4DMesh::setLineColor(U4DVector4n &lineColor){
        
        renderEntity->setGeometryLineColor(lineColor);
    }
    
    void U4DMesh::setVisibility(bool uValue){
        
        visibility=uValue;
        
    }
    
    bool U4DMesh::getVisibility(){
        
        return visibility;
    }

}
