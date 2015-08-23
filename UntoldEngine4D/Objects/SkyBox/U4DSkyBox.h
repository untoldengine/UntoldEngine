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
 *  Class in charge of skybox for the game
 */
class U4DSkyBox:public U4DVisibleEntity{
    
private:

public:
    
    U4DVertexData bodyCoordinates;
    U4DTextureData textureInformation;
    
    U4DSkyBox();
    
   
    ~U4DSkyBox(){};
    
    
    void initSkyBox(float uSize,const char* positiveXImage,const char* negativeXImage,const char* positiveYImage,const char* negativeYImage,const char* positiveZImage, const char* negativeZImage);
    
    
    
    void draw();
    
};
    
}

#endif /* defined(__UntoldEngine__U4DSkyBox__) */
