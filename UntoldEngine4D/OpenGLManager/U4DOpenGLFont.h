//
//  U4DOpenGLFont.h
//  UntoldEngine
//
//  Created by Harold Serrano on 12/19/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DOpenGLFont__
#define __UntoldEngine__U4DOpenGLFont__

#include <iostream>
#include "U4DOpenGLManager.h"
#include "U4DOpenGLImage.h"

namespace U4DEngine {
class U4DFont;
}

namespace U4DEngine {
    
class U4DOpenGLFont:public U4DOpenGLImage{
    
private:

    U4DImage* u4dObject;
    
public:
    
    U4DOpenGLFont(U4DImage* uU4DImage):U4DOpenGLImage(uU4DImage){
        u4dObject=uU4DImage; //attach the object to render
    };

    
    ~U4DOpenGLFont(){};
    
    void updateVertexObjectBuffer();
    
    void setImageDimension(float uWidth,float uHeight, float uAtlasWidth,float uAtlasHeight);
    
    void updateImageDimension(float uWidth,float uHeight, float uAtlasWidth,float uAtlasHeight);

};

}

#endif /* defined(__UntoldEngine__U4DOpenGLFont__) */
