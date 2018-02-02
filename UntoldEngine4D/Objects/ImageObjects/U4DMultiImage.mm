//
//  U4DMultiImage.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/26/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DMultiImage.h"
#include "U4DRenderMultiImage.h"

namespace U4DEngine {
    
    U4DMultiImage::U4DMultiImage():imageState(false){
        
        renderManager=new U4DRenderMultiImage(this);
        setShader("vertexMultiImageShader", "fragmentMultiImageShader");
        
    };

    U4DMultiImage::~U4DMultiImage(){

        delete renderManager;
    }



    U4DMultiImage::U4DMultiImage(const char* uTextureOne,const char* uTextureTwo,float uWidth,float uHeight){
        
        renderManager=new U4DRenderMultiImage(this);
        setShader("vertexMultiImageShader", "fragmentMultiImageShader");
        setImage(uTextureOne, uTextureTwo, uWidth, uHeight);
        
    }
    
    void U4DMultiImage::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        renderManager->render(uRenderEncoder);
    }
    
    void U4DMultiImage::setImage(const char* uTextureOne,const char* uTextureTwo,float uWidth,float uHeight){
        
        renderManager->setDiffuseTexture(uTextureOne);
        renderManager->setAmbientTexture(uTextureTwo);
        setImageDimension(uWidth, uHeight);
        renderManager->loadRenderingInformation();
    }
    
    bool U4DMultiImage::getImageState(){
        
        return imageState;
    }
    
    void U4DMultiImage::setImageState(bool uValue){
        
        imageState=uValue;
    }
    
    void U4DMultiImage::changeImage(){
        
        imageState=!imageState;
    
    }


}
