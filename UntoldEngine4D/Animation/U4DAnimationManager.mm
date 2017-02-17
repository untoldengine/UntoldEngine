//
//  U4DAnimationManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/16/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U4DAnimationManager.h"
#include "U4DAnimation.h"

namespace U4DEngine {
    
    U4DAnimationManager::U4DAnimationManager():currentAnimation(NULL),previousAnimation(NULL),nextAnimation(NULL){
        
    }
    
    U4DAnimationManager::~U4DAnimationManager(){
        
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
            
            currentAnimation=nextAnimation;
            
            if (currentAnimation->isAnimationPlaying()==false) {
                
                currentAnimation->play();
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
            currentAnimation->stop();
            
        }
        
        currentAnimation=NULL;
        
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

}
