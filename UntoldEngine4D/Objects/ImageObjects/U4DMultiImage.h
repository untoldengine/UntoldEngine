//
//  U4DMultiImage.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/26/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DMultiImage__
#define __UntoldEngine__U4DMultiImage__

#include <iostream>
#include "U4DImage.h"

namespace U4DEngine {
    
class U4DMultiImage:public U4DImage{
    
private:
    
    bool changeTheImage;
    
public:
    
    U4DMultiImage();
    
    ~U4DMultiImage();
    
    void setImages(const char* uTextureOne,const char* uTextureTwo,float uWidth,float uHeight);
    
    void changeImage();
    
    void draw();
};

}

#endif /* defined(__UntoldEngine__U4DMultiImage__) */
