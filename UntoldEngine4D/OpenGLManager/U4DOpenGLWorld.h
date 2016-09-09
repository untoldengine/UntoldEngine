//
//  U4DOpenGLWorld.h
//  UntoldEngine
//
//  Created by Harold Serrano on 1/13/15.
//  Copyright (c) 2015 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DOpenGLWorld__
#define __UntoldEngine__U4DOpenGLWorld__

#include <iostream>
#include "U4DOpenGLManager.h"

namespace U4DEngine {

class U4DWorld;

}


namespace U4DEngine {

/**
 @brief The U4DOpenGLWorld is in charge of rendering the game world entity
 */
class U4DOpenGLWorld:public U4DOpenGLManager{
    
private:
    
    /**
     @brief Pointer representing the world entity
     */
    U4DWorld *u4dWorld;
    
    /**
     @brief Framebuffer used for shadow-mapping rendering
     */
    GLuint offscreenFramebuffer;
    
public:
    
    /**
     @brief Constructor for the class
     
     @param uWorld It takes as a paramenter the entity representing the world in a game
     */
    U4DOpenGLWorld(U4DWorld *uWorld);
    
    /**
     @brief Destructor for the class
     */
    ~U4DOpenGLWorld();
    
    /**
     @brief Method which loads all Vertex Object Buffers used in rendering
     */
    void loadVertexObjectBuffer();
    
    /**
     @brief Method which enables the Vertices Attributes locations
     */
    void enableVerticesAttributeLocations();
    
    /**
     @brief Method which returns the absolute space of the entity
     
     @return Returns the entity absolure space-Orientation and Position
     */
    U4DDualQuaternion getEntitySpace();
    
    /**
     @brief Method which starts the glDrawElements routine
     */
    void drawElements();
    
    /**
     @brief Method which starts the Shadow mapping rendering operation
     */
    void startShadowMapPass();
    
    /**
     @brief Method which stops the Shadow mapping rendering operation
     */
    void endShadowMapPass();
    
    /**
     @brief Method which initializes a framebuffer used for shadows
     */
    void initShadowMapFramebuffer();
    
};
    
}

#endif /* defined(__UntoldEngine__U4DOpenGLWorld__) */
