//
//  U4DSceneActiveState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/18/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DSceneActiveState.h"
#include "U4DResourceLoader.h"
#include "U4DLayerManager.h"
#include "U4DScheduler.h"
#include "U4DCamera.h"

namespace U4DEngine {

    U4DSceneActiveState* U4DSceneActiveState::instance=0;

    U4DSceneActiveState::U4DSceneActiveState():safeToChangeState(false){

    }

    U4DSceneActiveState::~U4DSceneActiveState(){

    }

    U4DSceneActiveState* U4DSceneActiveState::sharedInstance(){

    if (instance==0) {
        instance=new U4DSceneActiveState(); 
    }

    return instance;

    }

    void U4DSceneActiveState::enter(U4DScene *uScene){
        
        safeToChangeState=false;
        
        //if the scene did not have a loading transition and multi-thread was not used to load
        //the componets during the loading state, then we need to initialize the components
        if(!uScene->componentsMultithreadLoaded){
            //set entity manager to main game scene
            uScene->gameWorld->init();
            uScene->gameModel->init();
        }
        
        
        uScene->componentsMultithreadLoaded=false;
        
    }
        
    void U4DSceneActiveState::execute(U4DScene *uScene, double dt){
        
        safeToChangeState=false;
        
        //update the game controller
        uScene->gameController->update(dt);
        
        //update the game model
        uScene->gameModel->update(dt);
        
        //update the entity manager
        uScene->gameWorld->entityManager->update(dt); //need to add dt to view
        
    }

    void U4DSceneActiveState::render(U4DScene *uScene, id <MTLRenderCommandEncoder> uRenderEncoder){
        
        uScene->gameWorld->entityManager->render(uRenderEncoder);
        
        safeToChangeState=true;
    }
        
    void U4DSceneActiveState::renderShadow(U4DScene *uScene, id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture){
        
        uScene->gameWorld->entityManager->renderShadow(uRenderShadowEncoder, uShadowTexture);
        
    }

    void U4DSceneActiveState::renderOffscreen(U4DScene *uScene, id <MTLRenderCommandEncoder> uOffscreenRenderEncoder, id<MTLTexture> uOffscreenTexture){
        
        uScene->gameWorld->entityManager->renderOffscreen(uOffscreenRenderEncoder, uOffscreenTexture); 
        
    }
    
    void U4DSceneActiveState::exit(U4DScene *uScene){
        
        //delete ALL components
        
        //get the resource loader object
        U4DResourceLoader *resourceLoader=U4DResourceLoader::sharedInstance();
        
        //get the layer manager
        U4DLayerManager *layerManager=U4DLayerManager::sharedInstance();
        
        //clear the container in my resource loader
        resourceLoader->clear();
        
        //clear the layer container and stack
        layerManager->clear();
        
        //reset camera
        U4DCamera *camera=U4DCamera::sharedInstance();
        
        camera->setCameraBehavior(nullptr);
        
        //unschedule all timers
        U4DScheduler *scheduler=U4DScheduler::sharedInstance();
        scheduler->unscheduleAllTimers();
        
    }

    bool U4DSceneActiveState::isSafeToChangeState(U4DScene *uScene){
        
        //do other things here before changing the state
        if (safeToChangeState) {
            return true;
        }else{
            return false;
        }
        
    }

}
