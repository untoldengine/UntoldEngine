//
//  U4DOpenGLDebugger.h
//  UntoldEngine
//
//  Created by Harold Serrano on 1/24/15.
//  Copyright (c) 2015 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DOpenGLDebugger__
#define __UntoldEngine__U4DOpenGLDebugger__

#include <iostream>
#include "U4DOpenGLManager.h"

namespace U4DEngine {
class U4DDebugger;
}

namespace U4DEngine {
    
/**
 @brief The U4DOpenGLDebugger is in charge of rendering debugging information
 */
class U4DOpenGLDebugger:public U4DOpenGLManager{
    
private:
    
    /**
     @brief Pointer representing the debugger entity
     */
    U4DDebugger *u4dDebugger;
    
public:
    
    /**
     @brief Constructor for the class
     
     @param uDebugger It takes as a paramenter the entity representing the debugger entity
     */
    U4DOpenGLDebugger(U4DDebugger *uDebugger);
    
    /**
     @brief Destructor for the class
     */
    ~U4DOpenGLDebugger();
    
    /**
     @brief Method which loads all Vertex Object Buffers used in rendering
     */
    void loadVertexObjectBuffer();
    
    /**
     @brief Method which enables the Vertices Attributes locations
     */
    void enableVerticesAttributeLocations();
    
    /**
     @brief Method which starts the OpenGL rendering operations
     */
    void draw();
    
    /**
     @brief Method which starts the glDrawElements routine
     */
    void drawElements();
};

}

#endif /* defined(__UntoldEngine__U4DOpenGLDebugger__) */
