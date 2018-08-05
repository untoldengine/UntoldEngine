//
//  U4DBlendAnimation.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/16/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DBlendAnimation_hpp
#define U4DBlendAnimation_hpp

#include <stdio.h>
#include "U4DCallback.h"
#include "U4DAnimationManager.h"

namespace U4DEngine {
    
    class U4DAnimation;
    class U4DModel;
    class U4DBoneData;
    class U4DTimer;
}

namespace U4DEngine {
    
    class U4DBlendAnimation {
        
    private:
        
        U4DAnimation *previousAnimation;
        
        U4DAnimation *nextAnimation;
        
        int keyframe;
        
        float interpolationTime;
        
        U4DModel    *u4dModel;
        
        U4DBoneData* rootBone;
        
        /**
         @brief 3D Animation scheduler
         */
        U4DCallback<U4DBlendAnimation> *scheduler;
        
        /**
         @brief 3D Animation timer
         */
        U4DTimer *timer;

        U4DAnimationManager *animationManager;
        
    public:
        
        U4DBlendAnimation(U4DAnimationManager *uAnimationManager);
        
        ~U4DBlendAnimation();
        
        void setAnimationsToBlend();
        
        void playBlendedAnimation();
        
        void runAnimation();
        
    };
    
}
#endif /* U4DBlendAnimation_hpp */
