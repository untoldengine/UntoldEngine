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
#include "U4DMatrix4n.h"

namespace U4DEngine {
class U4DModel;
class U4DBoneData;
class U4DTimer;
}

namespace U4DEngine {

/**
 @brief The U4DAnimation class implements 3D animations for 3D model entities
 */
class U4DAnimation{
    
private:
    
    /**
     @brief 3D Animation scheduler
     */
    U4DCallback<U4DAnimation> *scheduler;
    
    /**
     @brief 3D Animation timer
     */
    U4DTimer *timer;
    
    /**
     @todo document this
     */
    bool animationPlaying;
    
    /**
     @todo document this
     */
    bool playContinuousLoop;
    
public:

    /**
     @brief Constructor for the animation class
     @param uModel 3D model entity to attach the 3D animation to
     */
    U4DAnimation(U4DModel *uModel);
    
    /**
     @brief Destructor for the animation class
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
    U4DBoneData* rootBone;
    
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
     @todo document this
     */
    void pause();
    
    /**
     @brief Method which runs the 3D animation
     */
    void runAnimation();
    
    /**
     @todo document this
     */
    bool isAnimationPlaying();
    
    /**
     @todo document this
     */
    int getCurrentKeyframe();
    
    /**
     @todo document this
     */
    float getCurrentInterpolationTime();
    
    /**
     @todo document this
     */
    float getFPS();
    
    /**
     @todo document this
     */
    bool getIsUpdatingKeyframe();
    
    /**
     @todo document this
     */
    void setPlayContinuousLoop(bool uValue);
    
    /**
     @todo document this
     */
    bool getPlayContinuousLoop();
    
};

}

#endif /* defined(__UntoldEngine__U4DAnimation__) */
