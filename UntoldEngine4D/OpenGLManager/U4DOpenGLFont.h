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
    
/**
 @brief The U4DOpenGLFont class is in charge of rendering font entities
 */
class U4DOpenGLFont:public U4DOpenGLImage{
    
private:

    /**
     @brief Pointer representing the font entity
     */
    U4DImage* u4dObject;
    
public:
    
    /**
     @brief Constructor for the class
     
     @param uU4DImage It takes as a paramenter the entity representing the font entity
     */
    U4DOpenGLFont(U4DImage* uU4DImage);

    /**
     @brief Destructor for the class
     */
    ~U4DOpenGLFont();
    
    /**
     @brief Method which updates all Vertex Object Buffers used in rendering
     */
    void updateVertexObjectBuffer();
    
    /**
     @brief Method which sets the image(texture) dimension found in an atlas texture
     
     @param uWidth       Image width
     @param uHeight      Image height
     @param uAtlasWidth  Atlas width
     @param uAtlasHeight Atlas height
     */
    void setImageDimension(float uWidth,float uHeight, float uAtlasWidth,float uAtlasHeight);
    
    /**
     @brief Method which update the image(texture) dimension found in an atlas texture
     
     @param uWidth       Image width
     @param uHeight      Image height
     @param uAtlasWidth  Atlas width
     @param uAtlasHeight Atlas height
     */
    void updateImageDimension(float uWidth,float uHeight, float uAtlasWidth,float uAtlasHeight);

};

}

#endif /* defined(__UntoldEngine__U4DOpenGLFont__) */
