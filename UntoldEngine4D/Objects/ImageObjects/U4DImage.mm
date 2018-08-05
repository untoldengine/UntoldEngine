//
//  U4DImage.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/9/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DImage.h"
#include "U4DRenderImage.h"
#include "U4DDirector.h"

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
        setImageDimension(uWidth, uHeight);
        renderManager->loadRenderingInformation();
    }

    void U4DImage::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        renderManager->render(uRenderEncoder);
    }
    
    void U4DImage::setImageDimension(float uWidth,float uHeight){
        
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
 
}
