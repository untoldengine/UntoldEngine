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
    
    U4DGameObject::U4DGameObject(){
     
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
    
    void U4DGameObject::applyForce(U4DVector3n &uForce){
        
        setAwake(true);
        
        addForce(uForce);
        
    }

}





