//
//  U4DImage.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/9/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DImage.h"
#include "U4DOpenGLImage.h"

namespace U4DEngine {
    
U4DImage::U4DImage(){
    
    openGlManager=new U4DOpenGLImage(this);
    openGlManager->setShader("imageShader");
};

U4DImage::~U4DImage(){
    
    delete openGlManager;
    
}

U4DImage::U4DImage(const char* uTextureImage,float uWidth,float uHeight){
    
    openGlManager=new U4DOpenGLImage(this);
    openGlManager->setShader("imageShader");
    setImage(uTextureImage, uWidth, uHeight);
    
}

void U4DImage::setImage(const char* uTextureImage,float uWidth,float uHeight){
    
    openGlManager->setDiffuseTexture(uTextureImage);
    openGlManager->setImageDimension(uWidth, uHeight);
    openGlManager->loadRenderingInformation();
}

void U4DImage::draw(){
    
    openGlManager->draw();
}
 
}