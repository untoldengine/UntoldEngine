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
    
    void U4DGameObject::stopAllAnimations(){
        
        if (currentAnimation!=NULL) {
            currentAnimation->stop();
        }
        
        currentAnimation=NULL;
    }
    
    void U4DGameObject::playAnimation(){
        
        if (currentAnimation!=NULL) {
            
            if (currentAnimation->isAnimationPlaying()==false) {
                
                currentAnimation->start();
            }

        }
        
    }

    U4DAnimation* U4DGameObject::getAnimation(){
        
        return currentAnimation;
    }
    
}





