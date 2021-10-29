//
//  U4DAnimationManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/16/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DAnimationManager.h"
#include "U4DAnimation.h"
#include "U4DBlendAnimation.h"

namespace U4DEngine {
    
    U4DAnimationManager::U4DAnimationManager(U4DModel *uU4DModel):model(uU4DModel),currentAnimation(NULL),previousAnimation(NULL),nextAnimation(NULL), blendedStartKeyframe(0),blendedStartInterpolationTime(0.0){
        
        blendedAnimation=new U4DBlendAnimation(this);
        
        model->pAnimationManager=this;
    }
    
    U4DAnimationManager::~U4DAnimationManager(){
        
        delete blendedAnimation;
        
        //stop current animation if any
        removeCurrentPlayingAnimation();
        
        //erase the animation map and delete all animations
        removeAllAnimationsFromDictionary();
        
        model->pAnimationManager=nullptr;
        
    }
    
    
    void U4DAnimationManager::setAnimationToPlay(U4DAnimation* uAnimation){
        
        nextAnimation=uAnimation;
    }

    void U4DAnimationManager::setAnimationToPlay(std::string uAnimationName){
        U4DAnimation *animation=getAnimationFromDictionary(uAnimationName);
        nextAnimation=animation;
    }
    

    void U4DAnimationManager::pauseCurrentPlayingAnimation(){
        
        if (currentAnimation!=NULL) {
            
            currentAnimation->pause();
            
        }
        
    }
    

    void U4DAnimationManager::playAnimation(){
        
        if (nextAnimation!=NULL) {
            
            //play next animation
            currentAnimation=nextAnimation;
            
            if (previousAnimation!=NULL && getPlayBlendedAnimation()==true) {
                
                //play blended animation
                blendedAnimation->playBlendedAnimation();
                
            }else{
                
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
    

    void U4DAnimationManager::stopAnimation(){
        
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

    void U4DAnimationManager::loadAnimationToDictionary(std::list<std::string> uAnimationList){

        //get the list
        for (auto animationName:uAnimationList){
            
            auto entry=animationsMap.find(animationName);
            
            U4DAnimation *uAnimation=new U4DAnimation(model);
            
            if(model->loadAnimationToModel(uAnimation, animationName.c_str())){
                
                //Make sure we are not adding more than one animation to the model
                if (entry!=animationsMap.end()) {
                    
                    U4DAnimation *previousAnimation=std::move(entry->second);
                    
                    delete previousAnimation;
                    
                    animationsMap.insert({animationName,std::move(uAnimation)});
                    
                }else{
            
                    animationsMap.insert(std::make_pair(animationName,uAnimation));
                    
                }
                
            }
        }
        
    }

    U4DAnimation *U4DAnimationManager::getAnimationFromDictionary(std::string uAnimationName){

        std::map<std::string,U4DAnimation*>::iterator it=animationsMap.find(uAnimationName);
        U4DAnimation *animation=nullptr;
        
        if (it != animationsMap.end()) {
            animation=animationsMap.find(uAnimationName)->second;
        }
        
        return animation;
    }

    void U4DAnimationManager::removeAnimationFromDictionary(std::string uAnimationName){

        std::map<std::string,U4DAnimation*>::iterator it=animationsMap.find(uAnimationName);
        U4DAnimation *animation=nullptr;
        
        if (it != animationsMap.end()) {
            animation=animationsMap.find(uAnimationName)->second;
            
            animationsMap.erase(it);
            
            delete animation;
        }
        
        
    }

    void U4DAnimationManager::removeAllAnimationsFromDictionary(){
        
        //get all the keys from the map
        std::vector<std::string> keys;
          for (auto const& n : animationsMap) {
            keys.push_back(n.first);
          }
        
        //remove from map and delete animation
        for(auto const &n:keys){
            removeAnimationFromDictionary(n);
            
        }
        
    }
    

}
