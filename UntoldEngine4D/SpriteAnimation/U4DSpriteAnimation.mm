//
//  U4DSpriteAnimation.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/23/15.
//  Copyright (c) 2015 Untold Engine Studios. All rights reserved.
//

#include "U4DSpriteAnimation.h"
#include "CommonProtocols.h"
#include "U4DTimer.h"
#include "U4DSprite.h"
#include "U4DLogger.h"

namespace U4DEngine {
    
    U4DSpriteAnimation::U4DSpriteAnimation(U4DSprite *uSprite, SPRITEANIMATIONDATA &uSpriteAnimationData):animationPlaying(false),spriteAnimationFrame(0),spriteAnimationData(uSpriteAnimationData),sprite(uSprite){
    
    scheduler=new U4DCallback<U4DSpriteAnimation>;
    
    timer=new U4DTimer(scheduler);
    
}

U4DSpriteAnimation::~U4DSpriteAnimation(){
    
    scheduler->unScheduleTimer(timer);
    delete scheduler;
    delete timer;
    
}

void U4DSpriteAnimation::play(){
    
    U4DLogger *logger=U4DLogger::sharedInstance();
    
    if (spriteAnimationData.animationSprites.size()>0) {
        
        if (animationPlaying==false) {
            
            animationPlaying=true;
            
            scheduler->scheduleClassWithMethodAndDelay(this, &U4DSpriteAnimation::runAnimation, timer, spriteAnimationData.delay, true);
            
            
        }else{
            logger->log("Error: The sprite animation is currently playing. Can't play it again until it finishes.");
        }
        
    }else{
        logger->log("Error: The sprite animation could not be started because it has no sprite animations");
    }
    
}

void U4DSpriteAnimation::stop(){
    
    spriteAnimationFrame=0;
    animationPlaying=false;
    scheduler->unScheduleTimer(timer);
}
    
void U4DSpriteAnimation::pause(){
    
    animationPlaying=false;
    timer->setPause(true);
    
}

void U4DSpriteAnimation::runAnimation(){

    if (spriteAnimationFrame<spriteAnimationData.animationSprites.size()) {
        
        const char* currentSprite=spriteAnimationData.animationSprites.at(spriteAnimationFrame);
        
        sprite->updateSprite(currentSprite);
        
        spriteAnimationFrame++;
        
    }else{
        
        spriteAnimationFrame=0;
    
    }
    
}

}
