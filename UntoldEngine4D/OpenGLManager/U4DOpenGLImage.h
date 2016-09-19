//
//  U4DOpenGLImage.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DOpenGLImage__
#define __UntoldEngine__U4DOpenGLImage__

#include <iostream>
#include "U4DOpenGLManager.h"

namespace U4DEngine {
class U4DImage;
}

namespace U4DEngine {
    
/**
 @brief The U4DOpenGLImage is in charge of rendering the image entities
 */
class U4DOpenGLImage:public U4DOpenGLManager{
    
private:
    
protected:
    
    /**
     @brief Pointer representing the image entity
     */
    U4DImage *u4dObject;
    
public:
    
    /**
     @brief Constructor for the class
     
     @param uU4DImage It takes as a paramenter the entity representing the image entity
     */
    U4DOpenGLImage(U4DImage *uU4DImage);
    
    /**
     @brief Destructor for the class
     */
    ~U4DOpenGLImage();
    
    /**
     @brief Method which returns the camera perspective projection space
     */
    U4DMatrix4n getCameraPerspectiveView();
    
    /**
     @brief Method which returns the absolute space of the entity
     
     @return Returns the entity absolure space-Orientation and Position
     */
    U4DDualQuaternion getEntitySpace();
    
    /**
     @brief Method which loads all Vertex Object Buffers used in rendering
     */
    void loadVertexObjectBuffer();
    
    /**
     @brief Method which loads all Texture Object Buffers used in rendering
     */
    void loadTextureObjectBuffer();
    
    /**
     @brief Method which enables the Vertices Attributes locations
     */
    void enableVerticesAttributeLocations();
    
    /**
     @brief Method which starts the glDrawElements routine
     */
    void drawElements();
    
    /**
     @brief Method which activates the Texture Units used in rendering
     */
    virtual void activateTexturesUniforms();
    
    /**
     @brief Method which sets the dimension of the image(texture) to use
     
     @param uWidth  Image width
     @param uHeight Image height
     */
    virtual void setImageDimension(float uWidth,float uHeight);
    
    /**
     @brief Method which sets the diffuse-texture used for the entity
     
     @param uTexture Name of the diffuse-texture
     */
    virtual void setDiffuseTexture(const char* uTexture);
    
    /**
     @brief Method which returns the camera space
     
     @return Returns the camera space-Orientation and Position
     */
    U4DDualQuaternion getCameraSpace();

    
};

}
    
#endif /* defined(__UntoldEngine__U4DOpenGLImage__) */
