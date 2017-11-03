//
//  U4DSkyBox.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/18/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DSkybox.h"
#include "U4DCamera.h"
#include "U4DIndex.h"
#include "U4DRenderSkybox.h"

namespace U4DEngine {
    
    U4DSkybox::U4DSkybox(){
        renderManager=new U4DRenderSkybox(this);
        setShader("vertexSkyboxShader", "fragmentSkyboxShader");
    }
        
    U4DSkybox::~U4DSkybox(){

        delete renderManager;
        
    }
    
    void U4DSkybox::initSkyBox(float uSize,const char* positiveXImage,const char* negativeXImage,const char* positiveYImage,const char* negativeYImage,const char* positiveZImage, const char* negativeZImage){
        
        //add the images to the vector
        renderManager->addTexturesToSkyboxContainer(positiveXImage);
        renderManager->addTexturesToSkyboxContainer(negativeXImage);
        renderManager->addTexturesToSkyboxContainer(positiveYImage);
        renderManager->addTexturesToSkyboxContainer(negativeYImage);
        renderManager->addTexturesToSkyboxContainer(negativeZImage);
        renderManager->addTexturesToSkyboxContainer(positiveZImage);
        
        //calculate the vertices
        renderManager->setSkyboxDimension(uSize);
        renderManager->loadRenderingInformation();
        
    }
    
    void U4DSkybox::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        renderManager->render(uRenderEncoder);
        
    }
}

