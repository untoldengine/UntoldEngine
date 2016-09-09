//
//  U4DOpenGLMultiImage.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/28/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DOpenGLMultiImage__
#define __UntoldEngine__U4DOpenGLMultiImage__

#include <iostream>
#include "U4DOpenGLImage.h"
#include "U4DOpenGLManager.h"


namespace U4DEngine {

/**
 @brief The U4DOpenGLMultiImage class is in charge of rendering multi-image entities
 */
class U4DOpenGLMultiImage:public U4DOpenGLImage{
    
private:
    /**
     @brief Inform the engine to activate multi-image(texture) support
     */
    bool activateMultiTextureImage;
    
public:
    
    /**
     @brief Constructor for the class
     
     @param uU4DImage It takes as a paramenter the entity representing the multi-image entity
     */
    U4DOpenGLMultiImage(U4DImage *uU4DImage);
    
    /**
     @brief Destructor for the class
     */
    ~U4DOpenGLMultiImage();
    
    /**
     @brief Method which activates the Texture Units used in rendering
     */
    void activateTexturesUniforms();
    
    /**
     @brief Method which loads all Texture Object Buffers used in rendering
     */
    void loadTextureObjectBuffer();
    
    /**
     @brief Method which sets the ambient-texture used for the entity
     
     @param uTexture Name of the ambient-texture
     */
    virtual void setAmbientTexture(const char* uTexture);
    
    /**
     @brief Method which asks the engine to enable multi-image
     
     @param value Boolean variable to enable/disable multi-image support
     */
    void setMultiImageActiveImage(bool value);
};
    
}

#endif /* defined(__UntoldEngine__U4DOpenGLMultiImage__) */
