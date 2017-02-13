//
//  U4DGameObject.cpp
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DGameObject.h"
#include "U4DDigitalAssetLoader.h"

namespace U4DEngine {
    
    U4DGameObject::U4DGameObject():currentAnimation(NULL){
        

    
    }

    U4DGameObject::~U4DGameObject(){
    
    }
    
    U4DGameObject::U4DGameObject(const U4DGameObject& value){
    
    }
    
    U4DGameObject& U4DGameObject::operator=(const U4DGameObject& value){
        
        return *this;
    
    }
    
    bool U4DGameObject::loadModel(const char* uModelName, const char* uBlenderFile){
        
        U4DEngine::U4DDigitalAssetLoader *loader=U4DEngine::U4DDigitalAssetLoader::sharedInstance();
        
        if(loader->loadDigitalAssetFile(uBlenderFile) && loader->loadAssetToMesh(this,uModelName)){
                        
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
    
    
    void U4DGameObject::setAnimation(U4DAnimation* uAnimation){
        
        currentAnimation=uAnimation;
    }
    
    void U4DGameObject::pauseAnimation(){
        
        if (currentAnimation!=NULL) {
           
            currentAnimation->pause();
            
        }
        
    }
    
    void U4DGameObject::stopAnimation(){
        
        if (currentAnimation!=NULL) {
            currentAnimation->stop();
        }
        
    }
    
    void U4DGameObject::removeAnimation(){
        
        if (currentAnimation!=NULL) {
            currentAnimation->stop();
        }
        
        currentAnimation=NULL;
    }
    
    void U4DGameObject::playAnimation(){
        
        if (currentAnimation!=NULL) {
            
            if (currentAnimation->isAnimationPlaying()==false) {
                
                currentAnimation->play();
            }

        }
        
    }
    
    void U4DGameObject::playAnimationFromKeyframe(int uKeyframe){
        
        if (currentAnimation!=NULL) {
            
            if (currentAnimation->isAnimationPlaying()==false) {
                
                currentAnimation->playFromKeyframe(uKeyframe);
            }
            
        }
        
    }

    U4DAnimation* U4DGameObject::getAnimation(){
        
        return currentAnimation;
    }

    bool U4DGameObject::getIsAnimationUpdatingKeyframe(){
        
        if (currentAnimation!=NULL) {
            return currentAnimation->getIsUpdatingKeyframe();
        }
        
        return false;
    }
    
    int U4DGameObject::getAnimationCurrentKeyframe(){
        
        if (currentAnimation!=NULL) {
            return currentAnimation->getCurrentKeyframe();
        }
        
        return 0;
    }
    
    float U4DGameObject::getAnimationCurrentInterpolationTime(){
        if (currentAnimation!=NULL) {
            return currentAnimation->getCurrentInterpolationTime();
        }
        
        return 0.0;
    }
    
    float U4DGameObject::getAnimationFPS(){
        
        if (currentAnimation!=NULL) {
           
            return currentAnimation->getFPS();
    
        }
        
        return 0.0;
    }
    
    void U4DGameObject::setPlayAnimationContinuously(bool uValue){
        
        if (currentAnimation!=NULL) {
            
            currentAnimation->setPlayContinuousLoop(uValue);
            
        }

    }
    
    void U4DGameObject::applyForce(U4DVector3n &uForce){
        
        setAwake(true);
        
        addForce(uForce);
        
    }
    

}





