//
//  U4DAnimation.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/9/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DAnimation__
#define __UntoldEngine__U4DAnimation__

#include <iostream>
#include <vector>
#include <string>
#include "CommonProtocols.h"
#include "U4DCallback.h"

namespace U4DEngine {
class U4DModel;
class U4DBoneData;
class U4DTimer;
}

namespace U4DEngine {
    
class U4DAnimation{
    
private:
    
    U4DCallback<U4DAnimation> *scheduler;
    U4DTimer *timer;
    
public:

    U4DAnimation(U4DModel *uModel);
    
    ~U4DAnimation();
    
    U4DModel    *u4dModel;
    std::string      name;
    float fps;
    int keyframe;
    int keyframeRange;
    float interpolationTime;
   
    std::vector<ANIMATIONDATA> animationsContainer;
    U4DBoneData* rootBone;
    
    
    void start();
    void stop();
    
    void runAnimation();
    
    
};

}

#endif /* defined(__UntoldEngine__U4DAnimation__) */
