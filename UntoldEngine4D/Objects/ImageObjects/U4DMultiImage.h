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

/**
 @brief The U4DMultiImage class represents multi-images entities such as buttons with a pressed and a released image
 */
class U4DMultiImage:public U4DImage{
    
private:

    /**
     @brief Variable which represents an image-chage state
     */
    bool changeTheImage;
    
public:
    
    /**
     @brief Constructor of class
     */
    U4DMultiImage();
    
    /**
     @brief Destructor of class
     */
    ~U4DMultiImage();
    
    /**
     @brief Method which assins an image to the entity
     
     @param uTextureImage Name of texture image
     @param uWidth        Width of texture image
     @param uHeight       Height of texture image
     */
    void setImages(const char* uTextureOne,const char* uTextureTwo,float uWidth,float uHeight);
    
    /**
     @brief Method which changes the image being rendered
     */
    void changeImage();
    
    /**
     @brief Method which starts the rendering process of the entity
     */
    void draw();
};

}

#endif /* defined(__UntoldEngine__U4DMultiImage__) */
