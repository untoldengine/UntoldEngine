//
//  U4DAnimationManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/16/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DAnimationManager_hpp
#define U4DAnimationManager_hpp

#include <stdio.h>
#include <map>
#include <list>
#include "U4DModel.h"

namespace U4DEngine {
    
    class U4DAnimation;
    class U4DBlendAnimation;
    
}

namespace U4DEngine {
    
    /**
     @ingroup animation
     @brief The U4DAnimationManager class manages 3D animations for 3D model entities
     */
    class U4DAnimationManager {
        
    private:
        
        /**
         @todo document this
         */
        U4DModel *model;
        
        /**
         @brief Map containing all animations
         */
        std::map<std::string,U4DAnimation*> animationsMap;
        
        /**
         * @brief pointer to the current playing animation
         */
        U4DAnimation *currentAnimation;

        /**
         * @brief pointer to the previous animation
         */
        U4DAnimation *previousAnimation;

        /**
         * @brief pointer to the next animation
         */
        U4DAnimation *nextAnimation;
        
        /**
         * @brief pointer to the U4DBlendAnimation object
         * @details the engine provides a way to blend two animation smoothly. That is, the engine will smoothly transition from a current animation to the next animation.
         */
        U4DBlendAnimation* blendedAnimation;
        
        /**
         * @brief should blend the animations
         * @details The engine will smoothly transition from a current animation to the next animation.
         */
        bool playBlendedAnimation;
        
        /**
         * @brief Keyframe when the blending should start
         * @details You can set which keyframe to start the animation transition
         */
        int blendedStartKeyframe;
        
        /**
         * @brief Interpolation time when to blending should start  
         * @details you can set the interpolation time to start the animation transition
         */
        float blendedStartInterpolationTime;
        
    public:
        
        /**
         * @brief Class constructor
         * @details initializes the current, next and previous animations to null. It also creates the U4DBlendAnimation object
         */
        U4DAnimationManager(U4DModel *uU4DModel);
        
        /**
         * @brief Class destructor
         * @details releases the U4DBlendAnimation object
         */
        ~U4DAnimationManager();
        
        /**
         @brief sets which animation to play next
         */
        void setAnimationToPlay(U4DAnimation* uAnimation);
        
        /**
         @brief sets which animation to play next
         */
        void setAnimationToPlay(std::string uAnimationName);
        
        /**
         @brief pauses current animation
         */
        void pauseCurrentPlayingAnimation();
        
        /**
         @brief plays the animation 
         */
        void playAnimation();
        
        /**
         @brief plays the animation from a particular keyframe
         */
        void playAnimationFromKeyframe(int uKeyframe);
        
        /**
         * @brief Gets a pointer to the current playing animation
         * @return current playing animation
         */
        U4DAnimation* getCurrentPlayingAnimation();
        
        /**
         @brief stops the current animation
         */
        void stopAnimation();
        
        /**
         @brief removes the current playing animation
         @details It also sets the current animation as previous animation
         */
        void removeCurrentPlayingAnimation();
        
        /**
         @brief sets the current, previous and next animation as null
         */
        void removeAllAnimations();
        
        /**
         @brief determines if the engine is updating the animation keyframe
         @return true if the keyframe is being updated
         */
        bool getIsAnimationUpdatingKeyframe();
        
        /**
         @brief get animation current keyframe
         @return current keyframe being played
         */
        int getAnimationCurrentKeyframe();
        
        /**
         @brief get the current animation interpolation time
         @return current animation interpolation time
         */
        float getAnimationCurrentInterpolationTime();
        
        /**
         @brief get the animation frames-per-second
         @details the FPS is read from the blender script file. The blender script files contains the animation information
         @return current animation frames per second
         */
        float getAnimationFPS();
        
        /**
         * @brief set the next animation to play continuously
         * 
         * @param uValue true if the animation should play continuously
         */
        void setPlayNextAnimationContinuously(bool uValue);
        
        /**
         @brief get the current animation keyframe duration
         @return duration of keyframe
         */
        float getDurationOfCurrentAnimationKeyframe();
        
        /**
         * @brief Set if the the animations should be blended
         * @details The engine allows for two animation to be transitioned smoothly between each other
         * 
         * @param uValue true if the animation should be transitioned smoothly
         */
        void setPlayBlendedAnimation(bool uValue);
        
        /**
         @brief get if the current animation must be blended
         @return true if the animations should be blended
         */
        bool getPlayBlendedAnimation();
        
        /**
         @brief get pointer to the previous animation
         @return previous animation
         */
        U4DAnimation* getPreviousAnimation();
        
        /**
         @brief get pointer to the next animation to play
         @return next animation
         */
        U4DAnimation* getNextAnimation();
        
        /**
         @brief get the keyframe when the engine should blend the animations
         @return keyframe whent to blend the animations
         */
        int getBlendedStartKeyframe();
        
        /**
         @brief get the interpolation time when the engine should blend the animations
         @return interpolation time when to blend the animations
         */
        int getBlendedStartInterpolationTime();
        
        void loadAnimationToDictionary(std::list<std::string> uAnimationList);
        
        U4DAnimation * getAnimationFromDictionary(std::string uAnimationName);
        
        void removeAnimationFromDictionary(std::string uAnimationName);
        
        void removeAllAnimationsFromDictionary();
        
    };
    
}


#endif /* U4DAnimationManager_hpp */
