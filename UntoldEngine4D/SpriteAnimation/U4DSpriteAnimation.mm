//
//  U4DSpriteAnimation.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/23/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#include "U4DSpriteAnimation.h"
#include "CommonProtocols.h"
#include "U4DTimer.h"
#include "U4DSprite.h"

namespace U4DEngine {
    
U4DSpriteAnimation::U4DSpriteAnimation(U4DSprite *uSprite, SPRITEANIMATION &uSpriteAnimation){
    
    spriteAnimationFrame=0;
    spriteAnimation=uSpriteAnimation;
    
    sprite=uSprite;
    
    scheduler=new U4DCallback<U4DSpriteAnimation>;
    
    timer=new U4DTimer(scheduler);
    
}

U4DSpriteAnimation::~U4DSpriteAnimation(){
    
    delete scheduler;
    delete timer;
    
}

void U4DSpriteAnimation::start(){
    
    spriteAnimationFrame=0;
    scheduler->scheduleClassWithMethodAndDelay(this, &U4DSpriteAnimation::runAnimation, timer, spriteAnimation.delay, true);
    
}

void U4DSpriteAnimation::stop(){
    
    scheduler->unScheduleTimer(timer);
}

void U4DSpriteAnimation::runAnimation(){

    if (spriteAnimationFrame<spriteAnimation.animationSprites.size()) {
        
        const char* currentSprite=spriteAnimation.animationSprites.at(spriteAnimationFrame);
        
        sprite->changeSprite(currentSprite);
        
        spriteAnimationFrame++;
        
    }else{
        
        spriteAnimationFrame=0;
    
    }
    
}

}
