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
#include "U4DBoneData.h"


namespace U4DEngine {
    
    class U4DAnimation;
    class U4DModel;
    class U4DTimer;
}

namespace U4DEngine {
    
    /**
     @ingroup animation
     @brief The U4DBlendAnimation class smoothly blends two animations so that the transition is smooth
     */
    class U4DBlendAnimation {
        
    private:
        
        /**
         * @brief pointer to the previous animation
         */
        U4DAnimation *previousAnimation;
        
        /**
         * @brief pointer to the next animation
         */
        U4DAnimation *nextAnimation;
        
        /**
         * @brief keyframe to start blending the animations
         */
        int keyframe;
        
        /**
         * @brief interpolation time to blend the animations
         */
        float interpolationTime;
        
        /**
         * @brief U4DModel that owns the animation
         */
        U4DModel    *u4dModel;
        
        /**
         * @brief rootbone of the armature. Animations require an armature
         */
        U4DBoneData* rootBone;
        
        /**
         @brief 3D Animation scheduler
         */
        U4DCallback<U4DBlendAnimation> *scheduler;
        
        /**
         @brief 3D Animation timer
         */
        U4DTimer *timer;

        /**
         * @brief pointer to the animation manager
         */
        U4DAnimationManager *animationManager;
        
    public:
        
        /**
         * @brief Class constructor
         * @details sets the animation manager, initializes the scheduler and timer
         * 
         * @param uAnimationManager animation manager object
         */
        U4DBlendAnimation(U4DAnimationManager *uAnimationManager);
        
        /**
         * @brief Class destructor
         * @details releases the scheduler and timer
         */
        ~U4DBlendAnimation();
        
        /**
         * @brief Prepares animations to blend
         * @details prepares the previous and next animation to blend
         */
        void setAnimationsToBlend();
        
        /**
         * @brief sets us the callback to play the animations
         * @details The play animation does not start playing the animation. Instead it prepares the callback and initializers how often to call the runAnimation method
         */
        void playBlendedAnimation();
        
        /**
         * @brief Transforms the armature bone space
         * @details performs all the space transforms on the armature to create the illusion of animation
         */
        void runAnimation();
        
    };
    
}
#endif /* U4DBlendAnimation_hpp */
