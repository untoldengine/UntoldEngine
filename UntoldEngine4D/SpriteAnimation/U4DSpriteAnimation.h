//
//  U4DSpriteAnimation.h
//  UntoldEngine
//
//  Created by Harold Serrano on 4/23/15.
//  Copyright (c) 2015 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DSpriteAnimation__
#define __UntoldEngine__U4DSpriteAnimation__

#include <iostream>
#include "CommonProtocols.h"
#include "U4DSprite.h"
#include "U4DCallback.h"

namespace U4DEngine {

/**
 @brief The U4DSpriteAnimation class implements sprites animations
 */
class U4DSpriteAnimation{
    
private:
    
    /**
     @brief Frame for the sprite animation
     */
    int spriteAnimationFrame;
    
    /**
     @brief Pointer to the sprite entity
     */
    U4DSprite *sprite;
    
    /**
     @brief Sprite animation
     */
    SPRITEANIMATIONDATA spriteAnimationData;
    
    /**
     @brief Sprite Animation timer
     */
    U4DTimer *timer;
    
    /**
     @brief Sprite Animation scheduler
     */
    U4DCallback<U4DSpriteAnimation> *scheduler;
    
    /**
     @todo document this
     */
    bool animationPlaying;
    
public:
    
    /**
     @brief Constructor for the class
     
     @param uSprite             sprite entity
     @param uSpriteAnimation    sprite animation
     */
    U4DSpriteAnimation(U4DSprite *uSprite, SPRITEANIMATIONDATA &uSpriteAnimationData);
    
    /**
     @brief Destructor for the class
     */
    ~U4DSpriteAnimation();
    
    /**
     @brief Method which runs the animation
     */
    void runAnimation();
    
    /**
     @brief Method which starts the animation
     */
    void play();
    
    /**
     @brief Method which stops the animation
     */
    void stop();
    
    void pause();
    
};

}

#endif /* defined(__UntoldEngine__U4DSpriteAnimation__) */
