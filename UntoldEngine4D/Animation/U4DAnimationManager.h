//
//  U4DAnimationManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/16/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U4DAnimationManager_hpp
#define U4DAnimationManager_hpp

#include <stdio.h>

namespace U4DEngine {
    
    class U4DAnimation;
    class U4DBlendAnimation;
    
}

namespace U4DEngine {
    
    class U4DAnimationManager {
        
    private:
        U4DAnimation *currentAnimation;
        U4DAnimation *previousAnimation;
        U4DAnimation *nextAnimation;
        
        U4DBlendAnimation* blendedAnimation;
        
        bool playBlendedAnimation;
        
    public:
        
        U4DAnimationManager();
        
        ~U4DAnimationManager();
        
        /**
         @todo documetn this
         */
        void setNextAnimationToPlay(U4DAnimation* uAnimation);
        
        /**
         @todo document this
         */
        void pauseCurrentPlayingAnimation();
        
        /**
         @todo document this
         */
        void playAnimation();
        
        /**
         @todo document this
         */
        void playAnimationFromKeyframe(int uKeyframe);
        
        /**
         @todo document this
         */
        U4DAnimation* getCurrentPlayingAnimation();
        
        /**
         @todo document this
         */
        void stopCurrentPlayingAnimation();
        
        /**
         @todo document this
         */
        void removeCurrentPlayingAnimation();
        
        /**
         @todo document this
         */
        bool getIsAnimationUpdatingKeyframe();
        
        /**
         @todo document this
         */
        int getAnimationCurrentKeyframe();
        
        /**
         @todo document this
         */
        float getAnimationCurrentInterpolationTime();
        
        /**
         @todo document this
         */
        float getAnimationFPS();
        
        /**
         @todo document this
         */
        void setPlayNextAnimationContinuously(bool uValue);
        
        /**
         @todo document this
         */
        float getDurationOfCurrentAnimationKeyframe();
        
        /**
         @todo document this
         */
        void setPlayBlendedAnimation(bool uValue);
        
        /**
         @todo document this
         */
        bool getPlayBlendedAnimation();
        
        /**
         @todo document this
         */
        U4DAnimation* getPreviousAnimation();
        
        /**
         @todo document this
         */
        U4DAnimation* getNextAnimation();
    };
    
}


#endif /* U4DAnimationManager_hpp */
