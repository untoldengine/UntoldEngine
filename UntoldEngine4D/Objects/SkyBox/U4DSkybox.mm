//
//  U4DSkyBox.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/18/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DSkybox.h"
#include "U4DCamera.h"
#include "U4DIndex.h"
#include "U4DRenderSkybox.h"

namespace U4DEngine {
    
    U4DSkybox::U4DSkybox(){
        renderEntity=new U4DRenderSkybox(this);
        
        renderEntity->setPipelineForPass("skyboxpipeline",U4DEngine::finalPass);
        
    }
        
    U4DSkybox::~U4DSkybox(){

        delete renderEntity;
        
    }
    
    void U4DSkybox::initSkyBox(float uSize,const char* positiveXImage,const char* negativeXImage,const char* positiveYImage,const char* negativeYImage,const char* positiveZImage, const char* negativeZImage){
        
        //add the images to the vector
        textureInformation.texture0=positiveXImage;
        textureInformation.texture1=negativeXImage;
        textureInformation.texture2=positiveYImage;
        textureInformation.texture3=negativeYImage;
        textureInformation.texture4=negativeZImage;
        textureInformation.texture5=positiveZImage;
        
        //calculate the vertices
        setSkyboxDimension(uSize);
        renderEntity->loadRenderingInformation();
        
    }
    
    void U4DSkybox::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        renderEntity->render(uRenderEncoder);
        
    }
    
    void U4DSkybox::setSkyboxDimension(float uSize){
        
        float size=uSize*2.0;
        
        //side1
        
        
        U4DVector3n v1(-size,-size,size);
        U4DVector3n v2(-size,size,size);
        U4DVector3n v3(size,size,size);
        U4DVector3n v4(size,-size,size);
        
        bodyCoordinates.addVerticesDataToContainer(v1);
        bodyCoordinates.addVerticesDataToContainer(v2);
        bodyCoordinates.addVerticesDataToContainer(v3);
        bodyCoordinates.addVerticesDataToContainer(v4);
        
        
        //side2
        
        
        U4DVector3n v5(size,-size,-size);
        U4DVector3n v6(size,size,-size);
        U4DVector3n v7(-size,size,-size);
        U4DVector3n v8(-size,-size,-size);
        
        bodyCoordinates.addVerticesDataToContainer(v5);
        bodyCoordinates.addVerticesDataToContainer(v6);
        bodyCoordinates.addVerticesDataToContainer(v7);
        bodyCoordinates.addVerticesDataToContainer(v8);
        
        
        //side3
        
        U4DVector3n v9(-size,-size,-size);
        U4DVector3n v10(-size,size,-size);
        U4DVector3n v11(-size,size,size);
        U4DVector3n v12(-size,-size,size);
        
        bodyCoordinates.addVerticesDataToContainer(v9);
        bodyCoordinates.addVerticesDataToContainer(v10);
        bodyCoordinates.addVerticesDataToContainer(v11);
        bodyCoordinates.addVerticesDataToContainer(v12);
        
        
        //side4
        
        U4DVector3n v13(size,-size,size);
        U4DVector3n v14(size,size,size);
        U4DVector3n v15(size,size,-size);
        U4DVector3n v16(size,-size,-size);
        
        bodyCoordinates.addVerticesDataToContainer(v13);
        bodyCoordinates.addVerticesDataToContainer(v14);
        bodyCoordinates.addVerticesDataToContainer(v15);
        bodyCoordinates.addVerticesDataToContainer(v16);
        
        
        //side5
        
        U4DVector3n v17(-size,size,size);
        U4DVector3n v18(-size,size,-size);
        U4DVector3n v19(size,size,-size);
        U4DVector3n v20(size,size,size);
        
        bodyCoordinates.addVerticesDataToContainer(v17);
        bodyCoordinates.addVerticesDataToContainer(v18);
        bodyCoordinates.addVerticesDataToContainer(v19);
        bodyCoordinates.addVerticesDataToContainer(v20);
        
        
        //side6
        
        U4DVector3n v21(-size,-size,-size);
        U4DVector3n v22(-size,-size,size);
        U4DVector3n v23(size,-size,size);
        U4DVector3n v24(size,-size,-size);
        
        
        bodyCoordinates.addVerticesDataToContainer(v21);
        bodyCoordinates.addVerticesDataToContainer(v22);
        bodyCoordinates.addVerticesDataToContainer(v23);
        bodyCoordinates.addVerticesDataToContainer(v24);
        
        
        U4DIndex i1(0, 1, 2);
        U4DIndex i2(2, 3, 0);
        U4DIndex i3(4, 5, 6);
        U4DIndex i4(6, 7, 4);
        
        U4DIndex i5(8, 9, 10);
        U4DIndex i6(10, 11, 8);
        U4DIndex i7(12, 13, 14);
        U4DIndex i8(14, 15, 12);
        
        U4DIndex i9(16, 17, 18);
        U4DIndex i10(18, 19, 16);
        U4DIndex i11(20, 21, 22);
        U4DIndex i12(22, 23, 20);
        
        
        bodyCoordinates.addIndexDataToContainer(i1);
        bodyCoordinates.addIndexDataToContainer(i2);
        bodyCoordinates.addIndexDataToContainer(i3);
        bodyCoordinates.addIndexDataToContainer(i4);
        
        bodyCoordinates.addIndexDataToContainer(i5);
        bodyCoordinates.addIndexDataToContainer(i6);
        bodyCoordinates.addIndexDataToContainer(i7);
        bodyCoordinates.addIndexDataToContainer(i8);
        
        bodyCoordinates.addIndexDataToContainer(i9);
        bodyCoordinates.addIndexDataToContainer(i10);
        bodyCoordinates.addIndexDataToContainer(i11);
        bodyCoordinates.addIndexDataToContainer(i12);
        
        
    }

}

