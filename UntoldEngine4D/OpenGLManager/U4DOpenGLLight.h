//
//  U4DOpenGLLight.h
//  UntoldEngine
//
//  Created by Harold Serrano on 1/24/15.
//  Copyright (c) 2015 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DOpenGLLight__
#define __UntoldEngine__U4DOpenGLLight__

#include <iostream>
#include "U4DOpenGLManager.h"

namespace U4DEngine {
class U4DLights;
}

namespace U4DEngine {
    
class U4DOpenGLLight:public U4DOpenGLManager{
    
private:
    
    U4DLights *u4dLight;
    
public:
    
    U4DOpenGLLight(U4DLights *uLight){
        
        u4dLight=uLight;
    
    }
    
    ~U4DOpenGLLight(){};
    
    void loadVertexObjectBuffer();
    
    void enableVerticesAttributeLocations();
    
    U4DDualQuaternion getEntitySpace();
    
    void drawElements();
    
};

}

#endif /* defined(__UntoldEngine__U4DOpenGLLight__) */
