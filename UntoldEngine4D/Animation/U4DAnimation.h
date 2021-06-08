//
//  U4DAnimation.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/9/14.
//  Copyright (c) 2014 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DAnimation__
#define __UntoldEngine__U4DAnimation__

#include <iostream>
#include <vector>
#include <string>
#include "CommonProtocols.h"
#include "U4DCallback.h"
#include "U4DMatrix4n.h"
#include "U4DBoneData.h"
#include "U4DNode.h"

namespace U4DEngine {
class U4DModel;
class U4DTimer;
}

namespace U4DEngine {

/**
 @ingroup animation
 @brief The U4DAnimation class implements 3D animations for 3D model entities
 */
class U4DAnimation{
    
private:
    
    /**
     * @brief 3D Animation scheduler
     */
    U4DCallback<U4DAnimation> *scheduler;
    
    /**
     * @ brief animation timer object
     */
    U4DTimer *timer;
    
    /**
     @brief is the animation playing
     */
    bool animationPlaying;
    
    /**
     @todo should the animation play continously
     */
    bool playContinuousLoop;
    
    /**
     @todo duration of animation keyframe
     */
    float durationOfKeyframe;
    
    /**
     * @brief Can the animation be interrupted
     * @details You can set if the engine can interrupt the animation before it ends
     */
    bool isAllowedToBeInterrupted;
    
public:

    /**
     @brief Constructor for the animation class
     @details it initializes the scheduler and timer. It also gets access to the armature root bone
     @param uModel 3D model entity to attach the 3D animation to
     */
    U4DAnimation(U4DModel *uModel);
    
    /**
     @brief Destructor for the animation class
     @details releases the scheduler and timer
     */
    ~U4DAnimation();
    
    /**
     @brief Pointer to the 3D model entity that the 3D animation will attach to
     */
    U4DModel    *u4dModel;
    
    /**
     @brief Name of the 3D animation
     */
    std::string      name;
    
    /**
     @brief 3D animation frames-per-seconds
     */
    float fps;
    
    /**
     @brief 3D animation keyframes
     */
    int keyframe;
    
    /**
     @brief 3D animation keyframe range
     */
    int keyframeRange;
    
    /**
     @brief 3D animation keyframe interpolation time
     */
    float interpolationTime;
    
    /**
     @brief Modeler 3D animation transform space. e.g. A Blender 3D animation requires a transform matrix before it can be played in opengl properly
     */
    U4DMatrix4n modelerAnimationTransform;
    
    /**
     @brief Vector containing all the 3D animation data.
     */
    std::vector<ANIMATIONDATA> animationsContainer;
    
    /**
     @brief Pointer to the root bone of the model armature
     */
    U4DNode<U4DBoneData>* rootBone;
    
    /**
     @brief Method which plays the 3D animation
     */
    void play();
    
    /**
     @brief Method which plays the 3D animation
     */
    void playFromKeyframe(int uKeyframe);
    
    /**
     @brief Method which stops the 3D animation
     */
    void stop();
    
    /**
     @brief pause the 3D animation
     */
    void pause();
    
    /**
     @brief Runs the 3D animation
     */
    void runAnimation();
    
    /**
     @brief is the current animation playing
     */
    bool isAnimationPlaying();
    
    /**
     @brief set if animation is currently playing
     */
    void setAnimationIsPlaying(bool uValue);
    
    /**
     @brief get if the animation is currently playing
     */
    bool getAnimationIsPlaying();
    
    /**
     @brief get the current animation keyframe
     */
    int getCurrentKeyframe();
    
    /**
     @brief get the current interpolation time
     */
    float getCurrentInterpolationTime();
    
    /**
     @brief get the current animation frame-per-second
     */
    float getFPS();
    
    /**
     @brief is the keyframe currently being updated.
     @details this is determined by checking if the animation is currently playing and if the interpolation time is not zero
     */
    bool getIsUpdatingKeyframe();
    
    /**
     @brief set if the animation should play in a continous loop
     */
    void setPlayContinuousLoop(bool uValue);
    
    /**
     @brief get if the animation should play in a continuous loop
     */
    bool getPlayContinuousLoop();
    
    /**
     @brief get the duration of the keyframe
     */
    float getDurationOfKeyframe();
    
    /**
     @brief set if the engine is allowed to interrupt the animation while it is playing
     @details if this is set to false, the engine will wait until the animation has finished before it starts playing another animation
     */
    void setIsAllowedToBeInterrupted(bool uValue);
    
    /**
     @brief get if the engine is allowed to interrupt the animation while it is playing
     @details if this is set to false, the engine will wait until the animation has finished before it starts playing another animation
     */
    bool getIsAllowedToBeInterrupted();
    
};

}

#endif /* defined(__UntoldEngine__U4DAnimation__) */
