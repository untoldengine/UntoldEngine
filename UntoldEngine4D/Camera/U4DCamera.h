//
//  U4DCamera.h
//  UntoldEngine
//
//  Created by Harold Serrano on 5/15/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DCamera__
#define __UntoldEngine__U4DCamera__

#include <iostream>
#include "U4DEntity.h"
#include "U4DModel.h"
#include "U4DVector3n.h"
#include "U4DMatrix4n.h"
#include "U4DDualQuaternion.h"

namespace U4DEngine {
    
class U4DMath;
class U4DVector3n;
class U4DMatrix4n;
}

namespace U4DEngine {
    
class U4DCamera:public U4DEntity{
  
private:

    U4DMatrix4n projectionView;
    U4DMatrix4n orthographicView;
    
    static U4DCamera* instance;
    
protected:
    
     U4DCamera();
    
    ~U4DCamera();
    
public:

    static U4DCamera* sharedInstance();
    
    void setCameraProjectionView(float fov, float aspect, float near, float far);
    U4DMatrix4n getCameraProjectionView();
    
    void setCameraOrthographicView(float left, float right,float bottom,float top,float near, float far);
    U4DMatrix4n getCameraOrthographicView();
    
};
    
}

#endif /* defined(__UntoldEngine__U4DCamera__) */
