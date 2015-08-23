//
//  U4DVisibleEntity.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DVisibleEntity__
#define __UntoldEngine__U4DVisibleEntity__

#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <vector>
#include "CommonProtocols.h"
#include "U4DOpenGLManager.h"
#include "U4DDualQuaternion.h"
#include "U4DEntity.h"


//#define GL_BGR 0x80E0
#define OPENGL_ES

namespace U4DEngine {
    
class U4DVisibleEntity:public U4DEntity{
    
private:
    
protected:
    
public:
    
    U4DVisibleEntity(){
    
        
    
    };
    
    virtual ~U4DVisibleEntity(){}
    
    U4DVisibleEntity(const U4DVisibleEntity& value){};

    U4DVisibleEntity& operator=(const U4DVisibleEntity& value){ return *this;};
    
    
    U4DOpenGLManager   *openGlManager;
    
    virtual void draw(){};
    virtual void update(double dt){};
    
    void addCustomUniform(const char* uName,std::vector<float> uData);
    void addCustomUniform(const char* uName,U4DVector3n uData);
    void addCustomUniform(const char* uName,U4DVector4n uData);
    
    void updateUniforms(const char* uName,std::vector<float> uData);
    void updateUniforms(const char* uName,U4DVector3n uData);
    void updateUniforms(const char* uName,U4DVector4n uData);
    
    void loadRenderingInformation();
    
};
    
}

#endif /* defined(__UntoldEngine__U4DVisibleEntity__) */
