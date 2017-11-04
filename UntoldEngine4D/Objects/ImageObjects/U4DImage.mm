//
//  U4DImage.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/9/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DImage.h"
#include "U4DRenderImage.h"

namespace U4DEngine {
    
    U4DImage::U4DImage(){
        
        renderManager=new U4DRenderImage(this);
        setShader("vertexImageShader", "fragmentImageShader");
        
    };

    U4DImage::~U4DImage(){
        
        delete renderManager;
        
    }

    U4DImage::U4DImage(const char* uTextureImage,float uWidth,float uHeight){
        
        renderManager=new U4DRenderImage(this);
        setShader("vertexImageShader", "fragmentImageShader");
        setImage(uTextureImage, uWidth, uHeight);
        
    }

    void U4DImage::setImage(const char* uTextureImage,float uWidth,float uHeight){
        
        renderManager->setDiffuseTexture(uTextureImage);
        renderManager->setImageDimension(uWidth, uHeight);
        renderManager->loadRenderingInformation();
    }

    void U4DImage::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        renderManager->render(uRenderEncoder);
    }
 
}
