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
    
class U4DOpenGLDebugger:public U4DOpenGLManager{
    
private:
    
    U4DDebugger *u4dDebugger;
    
public:
    
    U4DOpenGLDebugger(U4DDebugger *uDebugger){
    
        u4dDebugger=uDebugger;
    
    };
    
    ~U4DOpenGLDebugger(){};
    
    void loadVertexObjectBuffer();
    
    void enableVerticesAttributeLocations();
    
    void draw();
    
    void drawElements();
};

}

#endif /* defined(__UntoldEngine__U4DOpenGLDebugger__) */
