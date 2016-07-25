//
//  U4DOpenGL3DModel.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DOpenGL3DModel__
#define __UntoldEngine__U4DOpenGL3DModel__

#include <iostream>
#include "U4DOpenGLManager.h"

namespace U4DEngine {
    
class U4DModel;

}

namespace U4DEngine {
    
class U4DOpenGL3DModel:public U4DOpenGLManager{
    
private:
    
    U4DModel *u4dObject;
    U4DMatrix4n lightSpaceMatrix;
    
public:
    
   
    U4DOpenGL3DModel(U4DModel *uU4DModel){
    
        u4dObject=uU4DModel;
    };
    
    
    ~U4DOpenGL3DModel(){};
    
    

    //BUFFERS Methods
    
    void loadVertexObjectBuffer();
    
    void loadTextureObjectBuffer();
    
    void enableVerticesAttributeLocations();
    
    void loadArmatureUniforms();
    
    void loadLightsUniforms();
    
    void loadHasTextureUniform();
    
    void drawElements();
    
    void activateTexturesUniforms();
    
    void setNormalBumpTexture(const char* uTexture);
    
    void loadMaterialsUniforms();
    
    U4DDualQuaternion getEntitySpace();
    
    U4DDualQuaternion getEntityLocalSpace();
    
    U4DVector3n getEntityAbsolutePosition();
    
    U4DVector3n getEntityLocalPosition();
    
    void loadDepthShadowUniform();
    
    void drawDepthOnFrameBuffer();

};
}

#endif /* defined(__UntoldEngine__U4DOpenGL3DModel__) */
