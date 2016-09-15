//
//  U4DSkyBox.h
//  UntoldEngine
//
//  Created by Harold Serrano on 8/18/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DSkyBox__
#define __UntoldEngine__U4DSkyBox__

#include <iostream>
#include <vector>
#include "U4DVisibleEntity.h"
#include "U4DOpenGLCubeMap.h"
#include "U4DVertexData.h"
#include "U4DTextureData.h"


namespace U4DEngine {

/**
 @brief The U4DSkyBox class represents skybox (cubemap) entities
 */
class U4DSkyBox:public U4DVisibleEntity{
    
private:

public:

    /**
     @brief Object which contains attribute data such as vertices, and uv-coordinates
     */
    U4DVertexData bodyCoordinates;
    
    /**
     @brief Object which contains texture information
     */
    U4DTextureData textureInformation;
    
    /**
     @brief Constructor of class
     */
    U4DSkyBox();
    
    /**
     @brief Destructor of class
     */
    ~U4DSkyBox();
    
    /**
     @brief Method which initialized the skybox with the six images
     
     @param uSize   Size of skybox
     @param positiveXImage  Name of image for +x face
     @param negativeXImage  Name of image for -x face
     @param positiveYImage  Name of image for +y face
     @param negativeYImage  Name of image for -y face
     @param positiveZImage  Name of image for +z face
     @param negativeZImage  Name of image for -z face
     */
    void initSkyBox(float uSize,const char* positiveXImage,const char* negativeXImage,const char* positiveYImage,const char* negativeYImage,const char* positiveZImage, const char* negativeZImage);
    
    /**
     @brief Method which starts the rendering process of the entity
     */
    void draw();
    
};
    
}

#endif /* defined(__UntoldEngine__U4DSkyBox__) */
