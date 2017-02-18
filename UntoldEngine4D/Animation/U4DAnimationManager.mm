//
//  U4DAnimationManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/16/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U4DAnimationManager.h"
#include "U4DAnimation.h"
#include "U4DBlendAnimation.h"

namespace U4DEngine {
    
    U4DAnimationManager::U4DAnimationManager():currentAnimation(NULL),previousAnimation(NULL),nextAnimation(NULL), blendedStartKeyframe(0),blendedStartInterpolationTime(0.0){
        
        blendedAnimation=new U4DBlendAnimation(this);
        
    }
    
    U4DAnimationManager::~U4DAnimationManager(){
        
        delete blendedAnimation;
        
    }
    
    
    void U4DAnimationManager::setNextAnimationToPlay(U4DAnimation* uAnimation){
        
        nextAnimation=uAnimation;
    }
    

    void U4DAnimationManager::pauseCurrentPlayingAnimation(){
        
        if (currentAnimation!=NULL) {
            
            currentAnimation->pause();
            
        }
        
    }
    

    void U4DAnimationManager::playAnimation(){
        
        if (nextAnimation!=NULL) {
            
            
            if (previousAnimation!=NULL && getPlayBlendedAnimation()==true) {
                
                //play blended animation
                blendedAnimation->playBlendedAnimation();
                
            }else{
                
                //play next animation
                currentAnimation=nextAnimation;
                
                if (currentAnimation->isAnimationPlaying()==false) {
                    
                    currentAnimation->play();
                }
                
            }
            
        }
        
    }
    

    void U4DAnimationManager::playAnimationFromKeyframe(int uKeyframe){
        
        if (nextAnimation!=NULL) {
            
            currentAnimation=nextAnimation;
            
            if (currentAnimation->isAnimationPlaying()==false) {
                
                currentAnimation->playFromKeyframe(uKeyframe);
            }
            
        }
        
    }
    

    U4DAnimation* U4DAnimationManager::getCurrentPlayingAnimation(){
        
        return currentAnimation;
        
    }
    

    void U4DAnimationManager::stopCurrentPlayingAnimation(){
        
        if (currentAnimation!=NULL) {
            currentAnimation->stop();
        }
        
    }
    

    void U4DAnimationManager::removeCurrentPlayingAnimation(){
        
        if (currentAnimation!=NULL) {
            
            previousAnimation=currentAnimation;
            
            blendedStartKeyframe=currentAnimation->getCurrentKeyframe();
            blendedStartInterpolationTime=currentAnimation->getCurrentInterpolationTime();
            
            currentAnimation->stop();
            
        }
        
        currentAnimation=NULL;
        
    }
    
    void U4DAnimationManager::removeAllAnimations(){
        
        if (currentAnimation!=NULL) {
            
            currentAnimation->stop();
            
        }
        
        currentAnimation=NULL;
        previousAnimation=NULL;
        nextAnimation=NULL;
        
    }
    

    bool U4DAnimationManager::getIsAnimationUpdatingKeyframe(){
        
        if (currentAnimation!=NULL) {
            return currentAnimation->getIsUpdatingKeyframe();
        }
        
        return false;
        
    }
    

    int U4DAnimationManager::getAnimationCurrentKeyframe(){
        
        if (currentAnimation!=NULL) {
            return currentAnimation->getCurrentKeyframe();
        }
        
        return 0;
        
    }
    

    float U4DAnimationManager::getAnimationCurrentInterpolationTime(){
        
        if (currentAnimation!=NULL) {
            return currentAnimation->getCurrentInterpolationTime();
        }
        
        return 0.0;
        
    }
    

    float U4DAnimationManager::getAnimationFPS(){
        
        if (currentAnimation!=NULL) {
            
            return currentAnimation->getFPS();
            
        }
        
        return 0.0;
        
    }
    

    void U4DAnimationManager::setPlayNextAnimationContinuously(bool uValue){
        
        if (nextAnimation!=NULL) {
            
            nextAnimation->setPlayContinuousLoop(uValue);
            
        }

    }
    
 
    float U4DAnimationManager::getDurationOfCurrentAnimationKeyframe(){
        
        if (currentAnimation!=NULL) {
            
            return currentAnimation->getDurationOfKeyframe();
            
        }
        
        return 0.0;
    
    }
    
    void U4DAnimationManager::setPlayBlendedAnimation(bool uValue){
        
        playBlendedAnimation=uValue;
    }
    
    bool U4DAnimationManager::getPlayBlendedAnimation(){
        
        return playBlendedAnimation;
        
    }
    
    U4DAnimation* U4DAnimationManager::getPreviousAnimation(){
        
        return previousAnimation;
    }
    
    U4DAnimation* U4DAnimationManager::getNextAnimation(){
        
        return nextAnimation;
    }
    
    int U4DAnimationManager::getBlendedStartKeyframe(){
        
        return blendedStartKeyframe;
    }
    
    int U4DAnimationManager::getBlendedStartInterpolationTime(){
        
        return blendedStartInterpolationTime;
    }
    
}
