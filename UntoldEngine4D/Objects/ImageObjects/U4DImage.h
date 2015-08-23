//
//  U4DImage.h
//  UntoldEngine
//
//  Created by Harold Serrano on 8/9/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DImage__
#define __UntoldEngine__U4DImage__

#include <iostream>
#include "U4DVisibleEntity.h"
#include "U4DVertexData.h"
#include "U4DTextureData.h"

namespace U4DEngine {
/**
 *  Class in charge of all images in the engine
 */
class U4DImage:public U4DVisibleEntity{
  
private:
    
protected:
    
    
public:
    
    U4DVertexData bodyCoordinates;
    U4DTextureData textureInformation;
    
    U4DImage();
    
    U4DImage(const char* uTextureImage,float uWidth,float uHeight);
    
    ~U4DImage();
   
    virtual void setImage(const char* uTextureImage,float uWidth,float uHeight);
    
    virtual void draw();
    
};
    
}

#endif /* defined(__UntoldEngine__U4DImage__) */
