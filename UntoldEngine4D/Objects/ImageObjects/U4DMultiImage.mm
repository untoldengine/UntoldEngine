//
//  U4DMultiImage.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/26/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DMultiImage.h"
#include "U4DOpenGLMultiImage.h"

namespace U4DEngine {
    
U4DMultiImage::U4DMultiImage():changeTheImage(false){
    
     openGlManager=new U4DOpenGLMultiImage(this);
     openGlManager->setShader("multiImageShader");
    
};

U4DMultiImage::~U4DMultiImage(){

    delete openGlManager;
}

void U4DMultiImage::setImages(const char* uTextureOne,const char* uTextureTwo,float uWidth,float uHeight){
    
    openGlManager->setDiffuseTexture(uTextureOne);
    openGlManager->setAmbientTexture(uTextureTwo);
    openGlManager->setImageDimension(uWidth, uHeight);
    openGlManager->loadRenderingInformation();
    
    std::vector<float> data={0.0};
    
    addCustomUniform("ChangeImage", data);
    
}

void U4DMultiImage::draw(){
    
    openGlManager->draw();
}

void U4DMultiImage::changeImage(){
    
    changeTheImage=!changeTheImage;
    
    if (changeTheImage==true) {
        
        std::vector<float> data{1.0};
        
        openGlManager->updateCustomUniforms("ChangeImage", data);
        
    }else{
        
        std::vector<float> data{0.0};
        
        openGlManager->updateCustomUniforms("ChangeImage", data);
        
    }
    
    //openGlManager->setMultiImageActiveImage(changeTheImage);
    
}

}
