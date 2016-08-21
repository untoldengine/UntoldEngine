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
class U4DOpenGLGeometry:public U4DOpenGLManager{
  
private:
    
    U4DBoundingVolume* u4dObject;
    
    GLuint elementBuffer;
    
public:
    
    
    U4DOpenGLGeometry(U4DBoundingVolume* uU4DGeometricObject);
   
    ~U4DOpenGLGeometry();
    
    void drawElements();
    
    void loadVertexObjectBuffer();
    
    void enableVerticesAttributeLocations();
    
    
    U4DDualQuaternion getEntitySpace();
    
    U4DDualQuaternion getEntityLocalSpace();
    
    U4DVector3n getEntityAbsolutePosition();
    
    U4DVector3n getEntityLocalPosition();
    
};

}

#endif /* defined(__UntoldEngine__U4DOpenGLGeometry__) */
