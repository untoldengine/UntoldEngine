//
//  U4DGameObject.cpp
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DGameObject.h"
#include "U4DDigitalAssetLoader.h"
#include "U4DAnimationManager.h"

namespace U4DEngine {
    
    U4DGameObject::U4DGameObject(){
     
        animationManager=new U4DAnimationManager();
        
    }

    U4DGameObject::~U4DGameObject(){
    
        delete animationManager;
    }
    
    U4DGameObject::U4DGameObject(const U4DGameObject& value){
    
    }
    
    U4DGameObject& U4DGameObject::operator=(const U4DGameObject& value){
        
        return *this;
    
    }
    
    bool U4DGameObject::loadModel(const char* uModelName, const char* uBlenderFile){
        
        U4DEngine::U4DDigitalAssetLoader *loader=U4DEngine::U4DDigitalAssetLoader::sharedInstance();
        
        if(loader->loadDigitalAssetFile(uBlenderFile) && loader->loadAssetToMesh(this,uModelName)){
            
            //init the culling bounding volume
            initCullingBoundingVolume();
            
            return true;
        }
        
        return false;
    }
    
    bool U4DGameObject::loadAnimationToModel(U4DAnimation *uAnimation, const char* uAnimationName, const char* uBlenderFile){
        
        U4DEngine::U4DDigitalAssetLoader *loader=U4DEngine::U4DDigitalAssetLoader::sharedInstance();
        
        if (loader->loadDigitalAssetFile(uBlenderFile) && loader->loadAnimationToMesh(uAnimation, uAnimationName)) {
            
            return true;
            
        }
        
        return false;
    }
    
    void U4DGameObject::setNextAnimationToPlay(U4DAnimation* uAnimation){
        
        animationManager->setNextAnimationToPlay(uAnimation);
    }
    
    void U4DGameObject::pauseCurrentPlayingAnimation(){
        
        animationManager->pauseCurrentPlayingAnimation();
        
    }
    
    void U4DGameObject::stopCurrentPlayingAnimation(){
        
        animationManager->stopCurrentPlayingAnimation();
        
    }
    
    void U4DGameObject::removeCurrentPlayingAnimation(){
        
        animationManager->removeCurrentPlayingAnimation();
        
    }
    
    void U4DGameObject::removeAllAnimations(){
        
        animationManager->removeAllAnimations();
        
    }
    
    void U4DGameObject::playAnimation(){
        
        animationManager->playAnimation();
        
    }
    
    void U4DGameObject::playAnimationFromKeyframe(int uKeyframe){
        
        animationManager->playAnimationFromKeyframe(uKeyframe);
    }
    

    U4DAnimation* U4DGameObject::getCurrentPlayingAnimation(){
        
        return animationManager->getCurrentPlayingAnimation();
        
    }

    bool U4DGameObject::getIsAnimationUpdatingKeyframe(){
        
        return animationManager->getIsAnimationUpdatingKeyframe();
    }
    
    int U4DGameObject::getAnimationCurrentKeyframe(){
        
        return animationManager->getAnimationCurrentKeyframe();
    }
    
    float U4DGameObject::getAnimationCurrentInterpolationTime(){
        
        return animationManager->getAnimationCurrentInterpolationTime();
    }
    
    float U4DGameObject::getAnimationFPS(){
        
        return animationManager->getAnimationFPS();
        
    }
    
    void U4DGameObject::setPlayNextAnimationContinuously(bool uValue){
        
        animationManager->setPlayNextAnimationContinuously(uValue);

    }
    
    void U4DGameObject::applyForce(U4DVector3n &uForce){
        
        setAwake(true);
        
        addForce(uForce);
        
    }
    
    float U4DGameObject::getDurationOfCurrentAnimationKeyframe(){
        
        return animationManager->getDurationOfCurrentAnimationKeyframe();
    }
    
    void U4DGameObject::setPlayBlendedAnimation(bool uValue){
        
        animationManager->setPlayBlendedAnimation(uValue);
        
    }

}





