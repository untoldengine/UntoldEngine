//
//  U4DOpenGLGeometry.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DOpenGLGeometry__
#define __UntoldEngine__U4DOpenGLGeometry__

#include <iostream>
#include "U4DOpenGLManager.h"

namespace U4DEngine {
class U4DBoundingVolume;
}

namespace U4DEngine {

/**
 @brief The U4DOpenGLGeometry is in charge of rendering geometric entities
 */
class U4DOpenGLGeometry:public U4DOpenGLManager{
  
private:
    
    /**
     @brief Pointer representing a bounding volume geometric entity
     */
    U4DBoundingVolume* u4dObject;
    
    /**
     @brief Pointer to the index buffer
     */
    GLuint elementBuffer;
    
public:
    
    /**
     @brief Constructor for the class
     
     @param uU4DGeometricObject It takes as a paramenter the entity representing the geometric entity
     */
    U4DOpenGLGeometry(U4DBoundingVolume* uU4DGeometricObject);
   
    /**
     @brief Destructor for the class
     */
    ~U4DOpenGLGeometry();
    
    /**
     @brief Method which starts the glDrawElements routine
     */
    void drawElements();
    
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
     @brief Method which returns the local space of the entity
     
     @return Returns the entity local space-Orientation and Position
     */
    U4DDualQuaternion getEntityLocalSpace();
    
    /**
     @brief Method which returns the absolute position of the entity
     
     @return Returns the entity absolute position
     */
    U4DVector3n getEntityAbsolutePosition();
    
    /**
     @brief Method which returns the local position of the entity
     
     @return Returns the entity local position
     */
    U4DVector3n getEntityLocalPosition();
    
};

}

#endif /* defined(__UntoldEngine__U4DOpenGLGeometry__) */
