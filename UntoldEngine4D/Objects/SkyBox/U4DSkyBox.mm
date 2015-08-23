//
//  U4DSkyBox.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/18/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DSkyBox.h"
#include "U4DCamera.h"
#include "U4DIndex.h"
#include "U4DOpenGLManager.h"

namespace U4DEngine {
    
U4DSkyBox::U4DSkyBox(){
    openGlManager=new U4DOpenGLCubeMap(this);
    openGlManager->setShader("SkyBoxShader");
};

void U4DSkyBox::initSkyBox(float uSize,const char* positiveXImage,const char* negativeXImage,const char* positiveYImage,const char* negativeYImage,const char* positiveZImage, const char* negativeZImage){
    
    //add the images to the vector
    openGlManager->cubeMapTextures.push_back(positiveXImage);
    openGlManager->cubeMapTextures.push_back(negativeXImage);
    openGlManager->cubeMapTextures.push_back(positiveYImage);
    openGlManager->cubeMapTextures.push_back(negativeYImage);
    openGlManager->cubeMapTextures.push_back(positiveZImage);
    openGlManager->cubeMapTextures.push_back(negativeZImage);
    
    //calculate the vertices
    openGlManager->setCubeMapDimension(uSize);
    openGlManager->loadRenderingInformation();
     
}


void U4DSkyBox::draw(){
    
    openGlManager->draw();
}

}

